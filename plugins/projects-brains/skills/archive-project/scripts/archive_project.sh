#!/usr/bin/env bash
# archive_project.sh: marks a project as archived. The folder is kept.
#
#   - status cell of the project's row in INDEX.md / INDICE.md -> "archived (YYYY-MM-DD)"
#   - a closing section appended to the project's PROGRESS.md / PROGRESSO.md
#
# Usage:
#   archive_project.sh --brain ~/Brains/acme --name client-portal --reason "Why it stopped and where it ended" [--no-git]

set -euo pipefail

BRAIN=""; NAME=""; REASON=""; GIT=1
TODAY="$(date +%Y-%m-%d)"

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --brain) BRAIN="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --reason) REASON="${2:-}"; shift 2 ;;
    --no-git) GIT=0; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

[ -n "$BRAIN" ] || die "--brain is required"
[ -n "$NAME" ] || die "--name is required"
[ -n "$REASON" ] || die "--reason is required (why it stopped and where it ended)"
BRAIN="${BRAIN/#\~/$HOME}"

if [ -e "$BRAIN/INDICE.md" ]; then
  INDEX="$BRAIN/INDICE.md"; PROGRESS="PROGRESSO.md"; LABEL="arquivado"; TITLE="Encerrado em"
elif [ -e "$BRAIN/INDEX.md" ]; then
  INDEX="$BRAIN/INDEX.md"; PROGRESS="PROGRESS.md"; LABEL="archived"; TITLE="Archived on"
else
  die "no INDEX.md or INDICE.md in $BRAIN: is this a brain?"
fi

DIR="$(find "$BRAIN/projects" -mindepth 1 -maxdepth 1 -type d \( -name "$NAME" -o -name "[0-9][0-9]-$NAME" \) 2> /dev/null | head -1)"
[ -n "$DIR" ] || die "project '$NAME' not found in $BRAIN/projects"
SLUG="$(basename "$DIR")"

# status column of the row whose first cell links to projects/<slug>/
result="$(python3 - "$INDEX" "$SLUG" "$LABEL ($TODAY)" "$LABEL" <<'PY'
import re, sys
path, slug, new_status, label = sys.argv[1:5]
lines = open(path, encoding="utf-8").read().split("\n")
link = re.compile(r"\]\(projects/" + re.escape(slug) + r"(/[^)]*)?\)")
for i, line in enumerate(lines):
    if not line.startswith("|"):
        continue
    cells = line.split("|")
    if len(cells) < 5 or not link.search(cells[1]):
        continue
    if cells[3].strip().startswith(label) or cells[3].strip() in ("arquivo", "archive"):
        print("already")
        sys.exit(0)
    cells[3] = f" {new_status} "
    lines[i] = "|".join(cells)
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    print("updated")
    sys.exit(0)
print("missing")
PY
)"

case "$result" in
  already) echo "already archived: $SLUG"; exit 0 ;;
  missing) echo "warning: no row for $SLUG in $INDEX; only $PROGRESS was updated" >&2 ;;
esac

PFILE="$DIR/$PROGRESS"
[ -e "$PFILE" ] || printf '# %s\n' "$SLUG" > "$PFILE"
printf '\n## %s %s\n\n%s\n' "$TITLE" "$TODAY" "$REASON" >> "$PFILE"
echo "archived      $SLUG"

if [ "$GIT" = 1 ] && git -C "$BRAIN" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  git -C "$BRAIN" add -- "$PFILE" "$INDEX"
  git -C "$BRAIN" commit -q -m "Archive project: ${SLUG}" -- "$PFILE" "$INDEX"
  if git -C "$BRAIN" remote get-url origin > /dev/null 2>&1; then
    branch="$(git -C "$BRAIN" branch --show-current)"
    git -C "$BRAIN" push -q origin "HEAD:${branch}" 2> /dev/null && echo "pushed        ${branch}" \
      || echo "warning: push refused; the change is committed locally only" >&2
  fi
fi
