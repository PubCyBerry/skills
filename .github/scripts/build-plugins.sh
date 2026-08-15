#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Build the plugin distribution tree from plugins.d/.
#
# The catalog ships skills two ways: `npx skills add` reads skills/
# directly, and a plugin marketplace install reads plugins/<name>/. The
# second needs real files inside the plugin directory (a Codex local
# install silently drops symlinks), so plugins/ duplicates content from
# skills/. Duplicated content drifts, therefore it is generated here and
# gated by --check in CI rather than edited by hand.
#
# Reads:
#   plugins.d/_defaults.yml     defaults merged into every plugin
#   plugins.d/_marketplace.yml  marketplace-level metadata
#   plugins.d/<name>.yml        one file per plugin (leading _ = include)
#   skills/<dir>/               the canonical skill trees
#
# Writes:
#   plugins/<name>/skills/<dir>/     copied skill trees
#   plugins/<name>/.claude-plugin/plugin.json
#   plugins/<name>/.codex-plugin/plugin.json
#   plugins/<name>/.cursor-plugin/plugin.json
#   plugins/<name>/README.md
#   .claude-plugin/marketplace.json
#   .cursor-plugin/marketplace.json
#   .agents/plugins/marketplace.json
#
# Usage:
#   build-plugins.sh           build in place
#   build-plugins.sh --check   build into a temp tree and diff; exit 1 on
#                              drift, changing nothing
#
# Dependencies: bash, yq (mikefarah v4), jq, git.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PLUGINS_D="${PLUGINS_D:-plugins.d}"
DEFAULTS="$PLUGINS_D/_defaults.yml"
MARKETPLACE="$PLUGINS_D/_marketplace.yml"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# jq on Git Bash for Windows writes CRLF. Command substitution absorbs
# it, but a file write or a process-substitution loop does not — so a
# tree built on Windows would differ from the same tree built on the CI
# runner and --check would report permanent drift. Normalize at every
# point where jq output leaves a $( ) capture.
nocr() { tr -d '\r'; }

if [ "$CHECK" -eq 1 ]; then
  OUT="$tmpdir/out"
else
  OUT="."
fi
mkdir -p "$OUT"

[ -f "$DEFAULTS" ]    || { echo "error: $DEFAULTS not found" >&2; exit 1; }
[ -f "$MARKETPLACE" ] || { echo "error: $MARKETPLACE not found" >&2; exit 1; }

shopt -s nullglob
plugin_files=()
for f in "$PLUGINS_D"/*.yml; do
  case "$(basename "$f")" in _*) continue ;; esac
  plugin_files+=("$f")
done
shopt -u nullglob

if [ ${#plugin_files[@]} -eq 0 ]; then
  echo "error: no plugin definitions in $PLUGINS_D/" >&2
  exit 1
fi

mp=$(yq -o=json -I0 '.' "$MARKETPLACE")

plugin_entries="$tmpdir/plugin-entries.json"
echo '[]' > "$plugin_entries"

for file in "${plugin_files[@]}"; do
  cfg=$(yq ea '. as $item ireduce ({}; . * $item)' "$DEFAULTS" "$file" -o=json)

  name=$(jq -r '.name // ""' <<< "$cfg")
  [ -n "$name" ] || { echo "error: $file has no name" >&2; exit 1; }
  if [ "$name" != "$(basename "$file" .yml)" ]; then
    echo "error: $file declares name '$name'; expected '$(basename "$file" .yml)'" >&2
    exit 1
  fi

  mode=$(jq -r '.skill_files // "copy"' <<< "$cfg")
  if [ "$mode" != "copy" ]; then
    echo "error: $file sets skill_files: $mode; only 'copy' is implemented" >&2
    exit 1
  fi

  root="$OUT/plugins/$name"
  rm -rf "$root"
  mkdir -p "$root/skills" "$root/.claude-plugin" "$root/.codex-plugin" "$root/.cursor-plugin"

  # ── bundled skills
  bundled=()
  while IFS= read -r src; do
    [ -n "$src" ] || continue
    src="${src%/}"
    if [ ! -f "$src/SKILL.md" ]; then
      # A curated skill can vanish between syncs (renamed upstream, or
      # dropped for missing artifacts). Warn and keep building so a
      # single missing skill cannot block the whole sync PR.
      echo "::warning::$file includes $src, which has no SKILL.md — skipping"
      continue
    fi
    dst="$root/skills/$(basename "$src")"
    mkdir -p "$dst"
    cp -r "$src/." "$dst/"
    bundled+=("$(basename "$src")")
  done < <(jq -r '.include_skills[]? // empty' <<< "$cfg" | nocr)

  if [ ${#bundled[@]} -eq 0 ]; then
    echo "error: plugin '$name' bundles no skills" >&2
    exit 1
  fi

  # ── plugin.json — Claude Code
  jq -S '{
    name, version, description,
    displayName: .display_name,
    author, homepage, repository, license,
    keywords: (.keywords // []),
    skills: ["./skills/"]
  }' <<< "$cfg" | nocr > "$root/.claude-plugin/plugin.json"

  # ── plugin.json — Codex (carries the richer interface block)
  jq -S '{
    name, version, description,
    author, homepage, repository, license,
    keywords: (.keywords // []),
    skills: "./skills/",
    interface: {
      displayName: .display_name,
      shortDescription: .short_description,
      longDescription: .long_description,
      developerName: .author.name,
      category: .category,
      capabilities: (.capabilities // []),
      websiteURL: (.website_url // .homepage),
      brandColor: .brand_color,
      defaultPrompt: (.default_prompts // [])
    }
  }' <<< "$cfg" | nocr > "$root/.codex-plugin/plugin.json"

  # ── plugin.json — Cursor
  jq -S '{
    name, version, description,
    author: { name: .author.name },
    homepage, repository, license,
    keywords: (.keywords // [])
  }' <<< "$cfg" | nocr > "$root/.cursor-plugin/plugin.json"

  # ── generated plugin README
  {
    echo "<!-- Generated by .github/scripts/build-plugins.sh — do not edit. -->"
    echo "<!-- Edit plugins.d/$(basename "$file") instead. -->"
    echo
    echo "# $(jq -r '.display_name // .name' <<< "$cfg")"
    echo
    jq -r '.long_description // .description' <<< "$cfg" | nocr | fold -s -w 78 | sed 's/ *$//'
    echo
    echo "## Install"
    echo
    echo '```bash'
    echo "# Claude Code"
    echo "/plugin marketplace add pubcyberry/skills"
    echo "/plugin install $name@$(jq -r '.name' <<< "$mp")"
    echo '```'
    echo
    echo "## Bundled skills"
    echo
    for s in "${bundled[@]}"; do
      echo "- [\`$s\`](skills/$s/SKILL.md)"
    done
    echo
    echo "Canonical copies live in [\`skills/\`](../../skills/) at the repository root."
  } | nocr > "$root/README.md"

  entry=$(jq -n --argjson cfg "$cfg" '{
    name: $cfg.name,
    description: $cfg.description,
    category: $cfg.category
  }')
  jq --argjson e "$entry" '. + [$e]' "$plugin_entries" | nocr > "$plugin_entries.tmp"
  mv "$plugin_entries.tmp" "$plugin_entries"

  echo "  ✓ plugins/$name (${#bundled[@]} skill(s): ${bundled[*]})"
done

entries=$(cat "$plugin_entries")

# ── marketplace manifests
mkdir -p "$OUT/.claude-plugin" "$OUT/.cursor-plugin" "$OUT/.agents/plugins"

jq -S -n --argjson mp "$mp" --argjson plugins "$entries" '{
  name: $mp.name,
  owner: $mp.owner,
  metadata: { description: $mp.description, version: $mp.version },
  plugins: [ $plugins[] | { name, source: ("./plugins/" + .name), description } ]
}' | nocr > "$OUT/.claude-plugin/marketplace.json"

jq -S -n --argjson mp "$mp" --argjson plugins "$entries" '{
  name: $mp.name,
  owner: { name: $mp.owner.name },
  metadata: { description: $mp.description, version: $mp.version },
  plugins: [ $plugins[] | { name, source: ("./plugins/" + .name), description } ]
}' | nocr > "$OUT/.cursor-plugin/marketplace.json"

jq -S -n --argjson mp "$mp" --argjson plugins "$entries" '{
  name: $mp.name,
  interface: { displayName: $mp.display_name },
  plugins: [ $plugins[] | {
    name,
    source: { source: "local", path: ("./plugins/" + .name) },
    policy: { installation: "AVAILABLE", authentication: "NONE" },
    category
  } ]
}' | nocr > "$OUT/.agents/plugins/marketplace.json"

if [ "$CHECK" -eq 0 ]; then
  echo "Built $(jq -r 'length' "$plugin_entries") plugin(s) and 3 marketplace manifest(s)"
  exit 0
fi

# ── check mode
status=0
compare_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "✗ $path is missing"
    return 1
  fi
  if ! diff -ru "$path" "$OUT/$path" > "$tmpdir/diff.txt" 2>&1; then
    echo "✗ $path is out of date:"
    sed 's/^/    /' "$tmpdir/diff.txt" | head -60
    return 1
  fi
  return 0
}

for file in "${plugin_files[@]}"; do
  compare_path "plugins/$(basename "$file" .yml)" || status=1
done
compare_path ".claude-plugin/marketplace.json"  || status=1
compare_path ".cursor-plugin/marketplace.json"  || status=1
compare_path ".agents/plugins/marketplace.json" || status=1

if [ "$status" -ne 0 ]; then
  echo
  echo "Run: bash .github/scripts/build-plugins.sh"
  exit 1
fi
echo "✓ plugin tree and marketplace manifests are up to date"
