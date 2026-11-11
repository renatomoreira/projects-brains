#!/usr/bin/env bash
# Runs the scaffold tests. Usage: bash tests/run.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD="$HERE/../plugins/projects-brains/skills/brains-setup/scripts/scaffold.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

ok()   { echo "PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL  $1"; FAIL=$((FAIL + 1)); }
tree() { (cd "$1" && find . \( -type f -o -type d -empty \) | sort); }
hashes() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 shasum | shasum); }

# 1. builds exactly the expected tree
bash "$SCAFFOLD" --root "$TMP/b" --fronts acme,personal > /dev/null
if diff <(tree "$TMP/b") "$HERE/expected-tree.txt" > "$TMP/diff.txt"; then
  ok "creates the expected tree"
else
  fail "creates the expected tree"; cat "$TMP/diff.txt"
fi

# 2. a second run changes nothing
before="$(hashes "$TMP/b")"
out="$(bash "$SCAFFOLD" --root "$TMP/b" --fronts acme,personal)"
after="$(hashes "$TMP/b")"
if [ "$before" = "$after" ] && echo "$out" | grep -q "0 files created"; then
  ok "second run is a no-op"
else
  fail "second run is a no-op"
fi

# 3. a file edited by the user is never overwritten
echo "my own notes" >> "$TMP/b/acme/AGENTS.md"
edited="$(shasum "$TMP/b/acme/AGENTS.md")"
bash "$SCAFFOLD" --root "$TMP/b" --fronts acme,personal > /dev/null
[ "$edited" = "$(shasum "$TMP/b/acme/AGENTS.md")" ] && ok "keeps user edits" || fail "keeps user edits"

# 4. dry run writes nothing
before="$(hashes "$TMP/b")"
bash "$SCAFFOLD" --root "$TMP/b" --fronts acme,personal,beta --dry-run > "$TMP/dry.txt"
after="$(hashes "$TMP/b")"
if [ "$before" = "$after" ] && [ ! -e "$TMP/b/beta" ] && grep -q "would create" "$TMP/dry.txt"; then
  ok "dry run writes nothing"
else
  fail "dry run writes nothing"
fi

# 5. adding a front later wires it into the mega-brain
bash "$SCAFFOLD" --root "$TMP/b" --fronts beta > /dev/null
if grep -q '"../beta"' "$TMP/b/mega-brain/.claude/settings.json" \
  && grep -q '"../acme"' "$TMP/b/mega-brain/.claude/settings.json" \
  && grep -q '](../beta/INDEX.md)' "$TMP/b/mega-brain/INDEX.md" \
  && python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$TMP/b/mega-brain/.claude/settings.json"; then
  ok "new front is added to the mega-brain"
else
  fail "new front is added to the mega-brain"
fi

# 6. rejects bad input
bad=0
bash "$SCAFFOLD" --root "$TMP/x" --fronts "Bad_Name" > /dev/null 2>&1 && bad=1
bash "$SCAFFOLD" --root "$TMP/x" --fronts "mega-brain" > /dev/null 2>&1 && bad=1
bash "$SCAFFOLD" --root "$TMP/x" --fronts "a,a" > /dev/null 2>&1 && bad=1
bash "$SCAFFOLD" --fronts "a" > /dev/null 2>&1 && bad=1
if [ "$bad" = 0 ] && [ ! -e "$TMP/x" ]; then ok "rejects bad input without writing"; else fail "rejects bad input without writing"; fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
