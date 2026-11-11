#!/usr/bin/env bash
# scaffold.sh: builds a "second brain" layout for AI coding agents.
#
#   <root>/
#     mega-brain/        reads every front (via additionalDirectories)
#     <front>/           one isolated repository per company, client or area
#
# Safe by design: it only creates what is missing. Existing files are never
# overwritten or deleted. The only edits to existing files are appending a new
# front to the mega-brain (settings.json and INDEX.md).
#
# Usage:
#   scaffold.sh --root ~/Brains --fronts acme,personal [--mega mega-brain] [--github] [--dry-run]

set -euo pipefail

ROOT=""
FRONTS=""
MEGA="mega-brain"
GITHUB=0
DRY=0
TODAY="$(date +%Y-%m-%d)"
RULE_TEMPLATE="$(cd "$(dirname "$0")/.." && pwd)/templates/new-project-rule.md"
CREATED=0
KEPT=0
UPDATED=0

die() { echo "error: $*" >&2; exit 1; }

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --fronts) FRONTS="${2:-}"; shift 2 ;;
    --mega) MEGA="${2:-}"; shift 2 ;;
    --github) GITHUB=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

[ -n "$ROOT" ] || die "--root is required"
[ -n "$FRONTS" ] || die "--fronts is required (comma separated, e.g. acme,personal)"
ROOT="${ROOT/#\~/$HOME}"

valid_slug() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }
valid_slug "$MEGA" || die "invalid mega-brain name '$MEGA': use lowercase letters, digits and dashes"

IFS=',' read -r -a FRONT_LIST <<< "$FRONTS"
[ "${#FRONT_LIST[@]}" -gt 0 ] || die "--fronts is empty"
for f in "${FRONT_LIST[@]}"; do
  valid_slug "$f" || die "invalid front name '$f': use lowercase letters, digits and dashes"
  [ "$f" != "$MEGA" ] || die "a front cannot have the same name as the mega-brain ('$MEGA')"
done
DUP="$(printf '%s\n' "${FRONT_LIST[@]}" | sort | uniq -d)"
[ -z "$DUP" ] || die "duplicate front name: $DUP"

# ---------------------------------------------------------------- helpers

mkd() {
  if [ -d "$1" ]; then return; fi
  if [ "$DRY" = 1 ]; then echo "would create  $1/"; else mkdir -p "$1"; fi
}

# write <file>: content comes from stdin, written only if the file does not exist
write() {
  local file="$1"
  if [ -e "$file" ]; then
    cat > /dev/null
    KEPT=$((KEPT + 1))
    return
  fi
  if [ "$DRY" = 1 ]; then
    cat > /dev/null
    echo "would create  $file"
  else
    mkdir -p "$(dirname "$file")"
    cat > "$file"
  fi
  CREATED=$((CREATED + 1))
}

keep() { write "$1/.gitkeep" < /dev/null; }

# ---------------------------------------------------------------- shared pieces

write_common() { # write_common <dir> <title>
  local d="$1" title="$2"
  mkd "$d"

  write "$d/CLAUDE.md" <<'EOF'
@AGENTS.md
@memory/MEMORY.md
EOF

  write "$d/memory/MEMORY.md" <<'EOF'
# Long-term memory

Always loaded. Keep it under 200 lines: one line per fact or pointer.

- **Hot:** this file.
- **Warm:** `topics/`, one subject per file, read when a line here points to it.
- **Cold:** `sessions/`, dated summaries, never loaded; search them when needed.

## Pointers
EOF
  keep "$d/memory/topics"
  keep "$d/memory/sessions"
  keep "$d/context"

  [ -r "$RULE_TEMPLATE" ] || die "missing template: $RULE_TEMPLATE"
  write "$d/.claude/rules/new-project.md" < "$RULE_TEMPLATE"

  write "$d/.gitignore" <<'EOF'
# Application code is never copied into a brain. Clone it here while you work.
projects/*/repo/
node_modules/
.env
.env.*
.DS_Store
CLAUDE.local.md
.claude/settings.local.json
.claude/worktrees/
EOF
  : "$title"
}

# ---------------------------------------------------------------- fronts

write_front() { # write_front <slug>
  local slug="$1" d="$ROOT/$1"
  write_common "$d" "$slug"
  keep "$d/projects"

  write "$d/AGENTS.md" <<EOF
# ${slug}

The brain of the **${slug}** front. Read by any coding agent (Claude Code, Codex, Copilot, Cursor).

## Read first

1. [INDEX.md](INDEX.md): projects, status and where everything lives.
2. [memory/MEMORY.md](memory/MEMORY.md): long-term memory (index).
3. The \`AGENTS.md\` and \`PROGRESS.md\` of the project you will work on, in \`projects/<project>/\`.

Load the minimum. Fetch the rest when the task needs it.

## Rules of this brain

- Files are the source of truth. What stays only in the chat is lost.
- Application code does not live here. A project's \`AGENTS.md\` points to the official remote. To work locally, \`git clone --depth 1\` into \`projects/<project>/repo/\` (ignored by git) and delete it when done.
- Decisions go to \`projects/<project>/decisions/YYYY-MM-DD-subject.md\`.
- Before ending a session, update the project's \`PROGRESS.md\` and, if something durable was learned, \`memory/\`.
- Never write passwords, tokens or keys to a file.
- Isolation: this repository does not read or mention other fronts.
EOF

  write "$d/INDEX.md" <<EOF
# Index: ${slug}

Created on ${TODAY}.

## Projects

| Project | What it is | Status | Code remote |
|---|---|---|---|

## Outside git

Large files (over 50 MB) that live only on the local disk or at their original remote.
EOF

  write "$d/.claude/settings.json" <<'EOF'
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)"
    ]
  }
}
EOF
}

# ---------------------------------------------------------------- mega-brain

write_mega() {
  local d="$ROOT/$MEGA"
  write_common "$d" "$MEGA"
  keep "$d/knowledge/inbox"
  keep "$d/knowledge/patterns"
  keep "$d/knowledge/decisions"

  write "$d/AGENTS.md" <<EOF
# ${MEGA}

The consolidated view across every front. It can read all of them; each front cannot read the others.

## Read first

1. [INDEX.md](INDEX.md): every front and where its index lives.
2. [PROGRESS.md](PROGRESS.md): what is in motion across fronts.
3. [memory/MEMORY.md](memory/MEMORY.md): long-term memory (index).

The fronts are the folders listed in \`additionalDirectories\` in \`.claude/settings.json\`. Their instruction files are **not** loaded automatically: open a front's \`INDEX.md\` or \`memory/MEMORY.md\` only when the question needs it.

## Rules

- Answer cross-front questions ("status of everything", "what is late", "where did we solve X before") by reading each front's \`INDEX.md\` and \`PROGRESS.md\`.
- Do not edit files inside a front from here. Note what should change and do it in a session opened in that front.
- \`knowledge/\` holds lessons that apply to more than one front. Never name a client or company there: write the pattern, not the case.
  - \`inbox/\`: raw candidates. \`patterns/\`: proven, reusable. \`decisions/\`: cross-front decisions with their reason.
- Never write passwords, tokens or keys to a file.
EOF

  write "$d/PROGRESS.md" <<EOF
# Progress

Updated on ${TODAY}.

## In motion

## Blocked

## Next
EOF

  write "$d/INDEX.md" <<EOF
# Index: all fronts

Created on ${TODAY}. Each front keeps its own \`INDEX.md\`; this file only points to them.

| Front | Index | Memory |
|---|---|---|
EOF

  # settings.json: create it, or append missing fronts to additionalDirectories
  local settings="$d/.claude/settings.json"
  local dirs="" f
  for f in "${FRONT_LIST[@]}"; do dirs="${dirs}${dirs:+,}\"../${f}\""; done
  if [ ! -e "$settings" ]; then
    write "$settings" <<EOF
{
  "additionalDirectories": [$(echo "$dirs" | sed 's/,/, /g')],
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)"
    ]
  }
}
EOF
  else
    KEPT=$((KEPT + 1))
    local missing=()
    for f in "${FRONT_LIST[@]}"; do
      grep -q "\"\.\./${f}\"" "$settings" || missing+=("$f")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
      if [ "$DRY" = 1 ]; then
        echo "would add     ${missing[*]} to additionalDirectories in $settings"
      elif command -v python3 > /dev/null; then
        python3 - "$settings" "${missing[@]}" <<'PY'
import json, sys
path, new = sys.argv[1], sys.argv[2:]
with open(path) as fh:
    data = json.load(fh)
dirs = data.setdefault("additionalDirectories", [])
for name in new:
    entry = f"../{name}"
    if entry not in dirs:
        dirs.append(entry)
with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
        UPDATED=$((UPDATED + 1))
        echo "updated       $settings (+${missing[*]})"
      else
        echo "warning: python3 not found; add ${missing[*]} to additionalDirectories in $settings by hand" >&2
      fi
    fi
  fi

  # INDEX.md: append a row for each front that is not listed yet
  local index="$d/INDEX.md"
  for f in "${FRONT_LIST[@]}"; do
    if [ "$DRY" = 1 ] && [ ! -e "$index" ]; then
      continue
    fi
    if ! grep -q "](\.\./${f}/INDEX.md)" "$index" 2> /dev/null; then
      if [ "$DRY" = 1 ]; then
        echo "would add     row for ${f} to $index"
      else
        echo "| ${f} | [INDEX.md](../${f}/INDEX.md) | [MEMORY.md](../${f}/memory/MEMORY.md) |" >> "$index"
      fi
    fi
  done
}

# ---------------------------------------------------------------- GitHub (optional)

github() {
  command -v git > /dev/null || die "git is required for --github"
  command -v gh > /dev/null || die "the GitHub CLI (gh) is required for --github"
  gh auth status > /dev/null 2>&1 || die "gh is not logged in: run 'gh auth login' first"
  local owner
  owner="$(gh api user -q .login)"

  local name dir repo
  for name in "$MEGA" "${FRONT_LIST[@]}"; do
    dir="$ROOT/$name"
    if [ "$name" = "$MEGA" ]; then repo="$MEGA"; else repo="${name}-brain"; fi

    if [ ! -d "$dir/.git" ]; then
      if [ "$DRY" = 1 ]; then
        echo "would run     git init + first commit in $dir"
      else
        git -C "$dir" init -q -b main
        git -C "$dir" add -A
        git -C "$dir" commit -q -m "Initial brain structure"
      fi
    fi

    if gh repo view "$owner/$repo" > /dev/null 2>&1; then
      echo "skipped       github.com/$owner/$repo already exists: nothing was pushed to it"
      continue
    fi
    if [ "$DRY" = 1 ]; then
      echo "would run     gh repo create $repo --private --source $dir --push"
    else
      gh repo create "$repo" --private --source "$dir" --remote origin --push > /dev/null
      echo "created       github.com/$owner/$repo (private)"
    fi
  done
}

# ---------------------------------------------------------------- main

[ "$DRY" = 1 ] && echo "dry run: nothing will be written"
mkd "$ROOT"
for f in "${FRONT_LIST[@]}"; do write_front "$f"; done
write_mega

if [ "$DRY" = 1 ]; then
  echo "summary: ${CREATED} files would be created, ${KEPT} already exist"
else
  echo "summary: ${CREATED} files created, ${KEPT} kept as they were, ${UPDATED} updated"
fi

[ "$GITHUB" = 1 ] && github
exit 0
