#!/usr/bin/env bash
# Runs the scaffold tests. Usage: bash tests/run.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD="$HERE/../plugins/projects-brains/skills/brains-setup/scripts/scaffold.sh"
NEWP="$HERE/../plugins/projects-brains/skills/new-project/scripts/new_project.sh"
ARCH="$HERE/../plugins/projects-brains/skills/archive-project/scripts/archive_project.sh"
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

# 7. new project in an English brain
bash "$NEWP" --brain "$TMP/b/acme" --name client-portal --summary "Customer portal" --no-git > /dev/null
P="$TMP/b/acme/projects/client-portal"
if [ -f "$P/AGENTS.md" ] && [ -f "$P/CLAUDE.md" ] && [ -f "$P/PROGRESS.md" ] \
  && grep -q '^| \[client-portal\](projects/client-portal/) | Customer portal | active |' "$TMP/b/acme/INDEX.md" \
  && awk '/^## Projects/{f=1;next} /^## /{f=0} f' "$TMP/b/acme/INDEX.md" | grep -q 'client-portal'; then
  ok "new project (English brain)"
else
  fail "new project (English brain)"; cat "$TMP/b/acme/INDEX.md"
fi

# 8. running it again duplicates nothing
before="$(hashes "$TMP/b/acme")"
out="$(bash "$NEWP" --brain "$TMP/b/acme" --name client-portal --summary "Customer portal" --no-git)"
[ "$before" = "$(hashes "$TMP/b/acme")" ] && echo "$out" | grep -q '^exists' && ok "new project is idempotent" || fail "new project is idempotent"

# 9. Portuguese brain with numbered projects
PT="$TMP/pt"; mkdir -p "$PT/projects/01-alpha" "$PT/projects/02-beta"
cat > "$PT/INDICE.md" <<'EOF'
# Índice: teste

## Projetos

| Projeto | O que é | Status | Remoto do código |
|---|---|---|---|
| [01-alpha](projects/01-alpha/) | A | ativo | — |
| [02-beta](projects/02-beta/) | B | operação | — |

## Fora do git
EOF
bash "$NEWP" --brain "$PT" --name portal --summary "Portal | novo" --no-git > /dev/null
if [ -f "$PT/projects/03-portal/PROGRESSO.md" ] \
  && sed -n '/^## Projetos/,/^## Fora/p' "$PT/INDICE.md" | grep -q '^| \[03-portal\](projects/03-portal/) | Portal - novo | ativo |' \
  && grep -q "Criado em" "$PT/projects/03-portal/AGENTS.md"; then
  ok "new project (Portuguese brain, numbered)"
else
  fail "new project (Portuguese brain, numbered)"; cat "$PT/INDICE.md"
fi

# 10. archive in English brain, then again
bash "$ARCH" --brain "$TMP/b/acme" --name client-portal --reason "Client cancelled." --no-git > /dev/null
if grep -q '| client-portal\|client-portal/) | Customer portal | archived (' "$TMP/b/acme/INDEX.md" \
  && grep -q "^## Archived on" "$P/PROGRESS.md" && grep -q "Client cancelled." "$P/PROGRESS.md" && [ -d "$P" ]; then
  before="$(hashes "$TMP/b/acme")"
  out="$(bash "$ARCH" --brain "$TMP/b/acme" --name client-portal --reason "again" --no-git)"
  [ "$before" = "$(hashes "$TMP/b/acme")" ] && echo "$out" | grep -q "already archived" && ok "archive project (English, idempotent)" || fail "archive project (English, idempotent)"
else
  fail "archive project (English, idempotent)"; cat "$TMP/b/acme/INDEX.md"
fi

# 11. archive in Portuguese brain by name without the number
bash "$ARCH" --brain "$PT" --name portal --reason "Encerrado." --no-git > /dev/null
grep -q '| \[03-portal\](projects/03-portal/) | Portal - novo | arquivado (' "$PT/INDICE.md" && grep -q "^## Encerrado em" "$PT/projects/03-portal/PROGRESSO.md" \
  && grep -q '| \[02-beta\](projects/02-beta/) | B | operação |' "$PT/INDICE.md" \
  && ok "archive project (Portuguese, only that row)" || fail "archive project (Portuguese, only that row)"

# 12. commit and push
G="$TMP/g"; git init -q --bare "$TMP/remote.git"
bash "$SCAFFOLD" --root "$G" --fronts acme > /dev/null
git -C "$G/acme" init -q -b main && git -C "$G/acme" add -A && git -C "$G/acme" -c user.name=t -c user.email=t@t commit -q -m init \
  && git -C "$G/acme" remote add origin "$TMP/remote.git" && git -C "$G/acme" push -q -u origin main 2> /dev/null
GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
  bash "$NEWP" --brain "$G/acme" --name website --summary "Site" > "$TMP/git.txt" 2>&1
if git -C "$TMP/remote.git" log -1 --format=%s main | grep -q "New project: website" && [ -z "$(git -C "$G/acme" status --porcelain)" ]; then
  ok "new project commits and pushes"
else
  fail "new project commits and pushes"; cat "$TMP/git.txt"
fi

# 13. rejects bad input
bad=0
bash "$NEWP" --brain "$PT" --name "Bad Name" --summary x --no-git > /dev/null 2>&1 && bad=1
bash "$NEWP" --brain "$TMP/nowhere" --name ok --summary x --no-git > /dev/null 2>&1 && bad=1
mkdir -p "$TMP/notabrain"; bash "$NEWP" --brain "$TMP/notabrain" --name ok --summary x --no-git > /dev/null 2>&1 && bad=1
bash "$ARCH" --brain "$PT" --name ghost --reason x --no-git > /dev/null 2>&1 && bad=1
[ "$bad" = 0 ] && [ ! -e "$TMP/notabrain/projects/ok" ] && ok "project scripts reject bad input" || fail "project scripts reject bad input"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
