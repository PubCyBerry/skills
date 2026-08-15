#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Prune catalog skill dirs whose components.d registration was removed.
#
# The sync only writes to dirs declared in components.d/*.yml — it never
# deletes a dir whose registration disappeared, so a deregistered skill
# would linger in the catalog (and in every downstream install surface)
# forever. Deregistering is meant to remove the mirror; this makes that
# true, and does it inside the sync commit where the deletion shows up in
# the PR diff.
#
# Safety rails, in order:
#   1. No components.d/*.yml at all → skip. Nothing has ever been synced,
#      so every skills/ dir is locally authored and none of them is an
#      orphan. Without this guard a first run on an unconfigured catalog
#      would delete the entire skills/ tree.
#   2. Any components.d or exceptions file fails to parse → skip the whole
#      run. A parse error makes that component's skills look unregistered,
#      which would mass-delete them.
#   3. More than PRUNE_CAP dirs would be pruned → delete nothing, write the
#      list to the overflow file, and surface it as a warning for a human.
#
# Outputs:
#   /tmp/pruned-orphans.txt           one pruned dir per line
#   /tmp/pruned-orphans-overflow.txt  cap exceeded — nothing was deleted

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PRUNE_CAP="${PRUNE_CAP:-5}"
EXCEPTIONS_FILE="${EXCEPTIONS_FILE:-catalog-exceptions.yml}"
pruned="${PRUNED_OUT:-/tmp/pruned-orphans.txt}"
overflow="${PRUNED_OVERFLOW_OUT:-/tmp/pruned-orphans-overflow.txt}"
: > "$pruned"
rm -f "$overflow"

shopt -s nullglob
component_files=(components.d/*.yml)
shopt -u nullglob

# Rail 1 — nothing registered means nothing was ever mirrored.
if [ ${#component_files[@]} -eq 0 ]; then
  echo "No components.d registrations — skipping orphan pruning (nothing is mirrored yet)."
  exit 0
fi

expected=$(mktemp)
trap 'rm -f "$expected" "$expected.orphans"' EXIT

# Declared set — every catalog_dir across components.d/*.yml.
for f in "${component_files[@]}"; do
  if ! yq e 'true' "$f" > /dev/null 2>&1; then
    echo "::warning::${f} failed to parse — skipping orphan pruning this run"
    exit 0
  fi
  yq -r '.skills[]?.catalog_dir // ""' "$f" | grep -v '^$' >> "$expected" || true
done

# Exceptions — dirs allowed to exist without a registration.
if [ -f "$EXCEPTIONS_FILE" ]; then
  if ! yq e 'true' "$EXCEPTIONS_FILE" > /dev/null 2>&1; then
    echo "::warning::${EXCEPTIONS_FILE} failed to parse — skipping orphan pruning this run"
    exit 0
  fi
  yq -r '.exceptions[]?.dir // ""' "$EXCEPTIONS_FILE" | grep -v '^$' >> "$expected" || true
fi

if [ ! -s "$expected" ]; then
  echo "::warning::declared skill set is empty — skipping orphan pruning this run"
  exit 0
fi

orphans="$expected.orphans"
: > "$orphans"
for d in skills/*/; do
  dir=$(basename "${d%/}")
  grep -qxF "$dir" "$expected" || echo "$dir" >> "$orphans"
done

count=$(wc -l < "$orphans" | tr -d ' ')
if [ "$count" -eq 0 ]; then
  echo "No orphaned skill dirs."
  exit 0
fi

# Rail 3 — cap.
if [ "$count" -gt "$PRUNE_CAP" ]; then
  cp "$orphans" "$overflow"
  echo "::warning::${count} orphaned skill dirs exceed the prune cap (${PRUNE_CAP}) — nothing deleted. Dirs:"
  sed 's/^/  /' "$orphans"
  exit 0
fi

while read -r dir; do
  git rm -rq "skills/$dir"
  echo "$dir" >> "$pruned"
  echo "  ✂ pruned skills/$dir (no components.d registration)"
done < "$orphans"
