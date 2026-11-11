#!/usr/bin/env bash
# new_project.sh: creates a project folder inside a brain and lists it in the brain's index.
#
#   <brain>/projects/<name>/AGENTS.md     what it is, scope, where the code lives
#   <brain>/projects/<name>/CLAUDE.md     @AGENTS.md
#   <brain>/projects/<name>/PROGRESS.md   state, blockers, next step (PROGRESSO.md in Portuguese brains)
#   + one row in the "## Projects" (or "## Projetos") table of INDEX.md (or INDICE.md)
#
# Follows the brain's conventions: Portuguese file names if the brain uses them, and
# a "nn-" number prefix if most existing projects have one. Never overwrites anything.
#
# Usage:
#   new_project.sh --brain ~/Brains/acme --name client-portal --summary "One line of scope" [--no-git] [--dry-run]

set -euo pipefail

BRAIN=""; NAME=""; SUMMARY=""; GIT=1; DRY=0
TODAY="$(date +%Y-%m-%d)"

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) BRAIN="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --summary) SUMMARY="${2:-}"; shift 2 ;;
    --no-git) GIT=0; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

[ -n "$BRAIN" ] || die "--brain is required"
[ -n "$NAME" ] || die "--name is required"
[ -n "$SUMMARY" ] || die "--summary is required (one line of scope)"
BRAIN="${BRAIN/#\~/$HOME}"
[ -d "$BRAIN" ] || die "brain folder not found: $BRAIN"
[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid name '$NAME': use lowercase letters, digits and dashes"
SUMMARY="${SUMMARY//|/-}"   # keep the index table intact

# ---- conventions of this brain
if [ -e "$BRAIN/INDICE.md" ]; then
  LANG_PT=1; INDEX="$BRAIN/INDICE.md"; PROGRESS="PROGRESSO.md"
elif [ -e "$BRAIN/INDEX.md" ]; then
  LANG_PT=0; INDEX="$BRAIN/INDEX.md"; PROGRESS="PROGRESS.md"
else
  die "no INDEX.md or INDICE.md in $BRAIN: is this a brain?"
fi

mkdir -p "$BRAIN/projects" 2> /dev/null || true

# same project already there, with or without a number prefix?
existing="$(find "$BRAIN/projects" -mindepth 1 -maxdepth 1 -type d \( -name "$NAME" -o -name "[0-9][0-9]-$NAME" \) 2> /dev/null | head -1)"
if [ -n "$existing" ]; then
  echo "exists        $existing: nothing was created"
  exit 0
fi

# number prefix if most projects use one
total=0; numbered=0; maxn=0
for d in "$BRAIN"/projects/*/; do
  [ -d "$d" ] || continue
  b="$(basename "$d")"
  total=$((total + 1))
  if [[ "$b" =~ ^([0-9]{2})- ]]; then
    numbered=$((numbered + 1))
    n=$((10#${BASH_REMATCH[1]}))
    [ "$n" -gt "$maxn" ] && maxn=$n
  fi
done
SLUG="$NAME"
if [ "$total" -gt 0 ] && [ $((numbered * 2)) -gt "$total" ] && [[ ! "$NAME" =~ ^[0-9]{2}- ]]; then
  SLUG="$(printf '%02d' $((maxn + 1)))-$NAME"
fi
DIR="$BRAIN/projects/$SLUG"
REL="projects/$SLUG/"

if [ "$DRY" = 1 ]; then
  echo "would create  $DIR/ (AGENTS.md, CLAUDE.md, $PROGRESS)"
  echo "would add     row for $SLUG to $INDEX"
  exit 0
fi

mkdir -p "$DIR"
printf '@AGENTS.md\n' > "$DIR/CLAUDE.md"

if [ "$LANG_PT" = 1 ]; then
  cat > "$DIR/AGENTS.md" <<EOF
# ${SLUG}

${SUMMARY}

Criado em ${TODAY}.

- **Estado:** [${PROGRESS}](${PROGRESS}). Leia primeiro.
- **Código:** — (se houver, aponte aqui o remoto oficial; clone local em \`repo/\`, ignorado pelo git).
- **Decisões:** \`decisions/AAAA-MM-DD-assunto.md\`.
EOF
  cat > "$DIR/$PROGRESS" <<EOF
# ${SLUG}: progresso

Atualizado em ${TODAY}.

## Estado

Projeto criado. ${SUMMARY}

## O que trava

## Próximo passo
EOF
  ROW="| [${SLUG}](${REL}) | ${SUMMARY} | ativo | — |"
  HEADING='^## Projetos'
  NEW_SECTION=$'## Projetos\n\n| Projeto | O que é | Status | Remoto do código |\n|---|---|---|---|'
else
  cat > "$DIR/AGENTS.md" <<EOF
# ${SLUG}

${SUMMARY}

Created on ${TODAY}.

- **State:** [${PROGRESS}](${PROGRESS}). Read it first.
- **Code:** — (if any, point to the official remote here; clone locally into \`repo/\`, ignored by git).
- **Decisions:** \`decisions/YYYY-MM-DD-subject.md\`.
EOF
  cat > "$DIR/$PROGRESS" <<EOF
# ${SLUG}: progress

Updated on ${TODAY}.

## State

Project created. ${SUMMARY}

## Blocked by

## Next step
EOF
  ROW="| [${SLUG}](${REL}) | ${SUMMARY} | active | — |"
  HEADING='^## Projects'
  NEW_SECTION=$'## Projects\n\n| Project | What it is | Status | Code remote |\n|---|---|---|---|'
fi

# ---- add the row to the projects table (after its last row), or create the section
if ! grep -q "](${REL})" "$INDEX"; then
  python3 - "$INDEX" "$HEADING" "$ROW" "$NEW_SECTION" <<'PY'
import re, sys
path, heading, row, new_section = sys.argv[1:5]
lines = open(path, encoding="utf-8").read().split("\n")
start = next((i for i, l in enumerate(lines) if re.match(heading, l)), None)
if start is None:
    while lines and lines[-1] == "":
        lines.pop()
    lines += ["", *new_section.split("\n"), row, ""]
else:
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    table = [i for i in range(start + 1, end) if lines[i].startswith("|")]
    if table:
        lines.insert(table[-1] + 1, row)
    else:
        block = new_section.split("\n")[2:] + [row]
        lines[start + 1:start + 1] = [""] + block
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
fi
echo "created       $DIR"

# ---- git
if [ "$GIT" = 1 ] && git -C "$BRAIN" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  git -C "$BRAIN" add -- "$DIR" "$INDEX"
  git -C "$BRAIN" commit -q -m "New project: ${SLUG}" -- "$DIR" "$INDEX"
  branch="$(git -C "$BRAIN" branch --show-current)"
  default="$(git -C "$BRAIN" symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null | sed "s#^origin/##" || true)"
  [ -n "$default" ] || default="main"
  if git -C "$BRAIN" remote get-url origin > /dev/null 2>&1; then
    if git -C "$BRAIN" push -q origin "HEAD:${branch}" 2> /dev/null; then
      echo "pushed        ${branch}"
    else
      echo "warning: push refused; the project is committed locally only" >&2
    fi
    if [ "$branch" != "$default" ]; then
      echo "warning: committed on '${branch}', not '${default}'. Merge it so new sessions see the project." >&2
    fi
  fi
fi
