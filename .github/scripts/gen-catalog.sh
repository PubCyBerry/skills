#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Regenerate every catalog surface from the skills themselves.
#
# Source of truth: the YAML frontmatter of each skills/<dir>/SKILL.md.
# Nothing here is hand-maintained, which is the point — a hand-maintained
# catalog table drifts from the skills it describes, and a stale index is
# worse than no index.
#
# Writes:
#   README.md      — the block between <!-- skills-table-start --> and
#                    <!-- skills-table-end --> is replaced.
#   skills.sh.json — skills.sh marketplace groupings, built from
#                    metadata.group + .github/scripts/skill-groups.yml.
#
# Usage:
#   gen-catalog.sh            regenerate in place
#   gen-catalog.sh --check    fail (exit 1) with a diff if either file is
#                             out of date; changes nothing. Used by CI.
#
# Dependencies: bash, yq (mikefarah v4), jq, git.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

SKILLS_DIR="${SKILLS_DIR:-skills}"
GROUPS_FILE="${GROUPS_FILE:-.github/scripts/skill-groups.yml}"
README_FILE="${README_FILE:-README.md}"
SKILLS_SH_FILE="${SKILLS_SH_FILE:-skills.sh.json}"
SKILLS_SH_SCHEMA="https://skills.sh/schemas/skills.sh.schema.json"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

frontmatter() {
  awk '
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit 1 }
    NR == 1 { next }
    /^---[[:space:]]*$/ { found = 1; exit }
    { print }
    END { if (!found) exit 1 }
  ' "$1"
}

# Collapse to a single line and escape the cell separator, so a
# description containing a pipe cannot break the table.
md_cell() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/  */ /g; s/|/\\|/g; s/^ //; s/ $//'
}

# ── 1. Read every skill once into a TSV: name, group, kind, lang, summary
facts="$tmpdir/skills.tsv"
: > "$facts"

shopt -s nullglob
skill_dirs=("$SKILLS_DIR"/*/)
shopt -u nullglob

if [ ${#skill_dirs[@]} -eq 0 ]; then
  echo "error: no skills found under $SKILLS_DIR/" >&2
  exit 1
fi

for dir in "${skill_dirs[@]}"; do
  dir="${dir%/}"
  name=$(basename "$dir")
  [ -f "$dir/SKILL.md" ] || { echo "error: $dir/SKILL.md is missing" >&2; exit 1; }

  fm=$(frontmatter "$dir/SKILL.md") || {
    echo "error: $dir/SKILL.md has no YAML frontmatter" >&2
    exit 1
  }

  group=$(printf '%s\n' "$fm" | yq -r '.metadata.group // ""')
  kind=$(printf '%s\n' "$fm" | yq -r '.metadata.kind // ""')
  lang=$(printf '%s\n' "$fm" | yq -r '.metadata.language // ""')
  summary=$(printf '%s\n' "$fm" | yq -r '.metadata.summary // .description // ""')

  for pair in "group:$group" "kind:$kind" "language:$lang" "summary:$summary"; do
    if [ -z "${pair#*:}" ]; then
      echo "error: $dir/SKILL.md frontmatter is missing metadata.${pair%%:*}" >&2
      exit 1
    fi
  done

  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$group" "$kind" "$lang" "$(md_cell "$summary")" >> "$facts"
done

sort -o "$facts" "$facts"

# ── 2. Every declared group key must exist in skill-groups.yml
group_keys="$tmpdir/group-keys.txt"
yq -r '.groups[].key' "$GROUPS_FILE" > "$group_keys"

while IFS=$'\t' read -r name group _; do
  grep -qxF "$group" "$group_keys" || {
    echo "error: skill '$name' declares metadata.group '$group', which is not in $GROUPS_FILE" >&2
    exit 1
  }
done < "$facts"

# ── 3. README table
table="$tmpdir/table.md"
{
  echo "| Skill | Group | Kind | Lang | Summary |"
  echo "|-------|-------|------|------|---------|"
  while IFS=$'\t' read -r name group kind lang summary; do
    title=$(yq -r ".groups[] | select(.key == \"$group\") | .title" "$GROUPS_FILE")
    printf '| [`%s`](%s/%s/SKILL.md) | %s | %s | %s | %s |\n' \
      "$name" "$SKILLS_DIR" "$name" "$title" "$kind" "$lang" "$summary"
  done < "$facts"
} > "$table"

readme_new="$tmpdir/README.md"
awk -v table_file="$table" '
  /<!-- skills-table-start -->/ {
    print
    while ((getline line < table_file) > 0) print line
    close(table_file)
    inside = 1
    next
  }
  /<!-- skills-table-end -->/ { inside = 0; print; next }
  !inside { print }
' "$README_FILE" > "$readme_new"

if ! grep -q '<!-- skills-table-start -->' "$README_FILE" || \
   ! grep -q '<!-- skills-table-end -->' "$README_FILE"; then
  echo "error: $README_FILE is missing the skills-table marker pair" >&2
  exit 1
fi

# ── 4. skills.sh.json — declared group order, empty groups omitted
skillssh_new="$tmpdir/skills.sh.json"
{
  printf '{\n'
  printf '  "$schema": "%s",\n' "$SKILLS_SH_SCHEMA"
  printf '  "notGrouped": "bottom",\n'
  printf '  "groupings": [\n'

  first=1
  while IFS= read -r key; do
    members=$(awk -F'\t' -v g="$key" '$2 == g { print $1 }' "$facts")
    [ -n "$members" ] || continue

    title=$(yq -r ".groups[] | select(.key == \"$key\") | .title" "$GROUPS_FILE")
    desc=$(yq -r ".groups[] | select(.key == \"$key\") | .description" "$GROUPS_FILE" | tr '\n' ' ' | sed 's/  */ /g; s/ $//')

    [ "$first" -eq 1 ] || printf ',\n'
    first=0

    printf '    {\n'
    printf '      "title": %s,\n' "$(printf '%s' "$title" | jq -Rs .)"
    printf '      "description": %s,\n' "$(printf '%s' "$desc" | jq -Rs .)"
    printf '      "skills": [\n'
    printf '%s\n' "$members" | sort | awk 'NR>1 { printf ",\n" } { printf "        \"%s\"", $0 } END { printf "\n" }'
    printf '      ]\n'
    printf '    }'
  done < "$group_keys"

  printf '\n  ]\n'
  printf '}\n'
} > "$skillssh_new"

jq -e . "$skillssh_new" > /dev/null || {
  echo "error: generated skills.sh.json is not valid JSON" >&2
  exit 1
}

# ── 5. Apply or check
status=0

compare() {
  local current="$1" generated="$2" label="$3"
  if [ ! -f "$current" ]; then
    echo "✗ $label does not exist"
    return 1
  fi
  if ! diff -u "$current" "$generated" > "$tmpdir/diff.txt"; then
    echo "✗ $label is out of date:"
    sed 's/^/    /' "$tmpdir/diff.txt"
    return 1
  fi
  echo "✓ $label is up to date"
  return 0
}

if [ "$CHECK" -eq 1 ]; then
  compare "$README_FILE" "$readme_new" "$README_FILE (skills table)" || status=1
  compare "$SKILLS_SH_FILE" "$skillssh_new" "$SKILLS_SH_FILE" || status=1
  if [ "$status" -ne 0 ]; then
    echo
    echo "Run: bash .github/scripts/gen-catalog.sh"
  fi
  exit "$status"
fi

cp "$readme_new" "$README_FILE"
cp "$skillssh_new" "$SKILLS_SH_FILE"

count=$(wc -l < "$facts" | tr -d ' ')
groups=$(jq -r '.groupings | length' "$SKILLS_SH_FILE")
echo "Regenerated $README_FILE table and $SKILLS_SH_FILE — $count skill(s) across $groups group(s)"
