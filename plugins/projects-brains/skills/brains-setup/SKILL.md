---
name: brains-setup
description: Set up a "second brain" folder structure for AI coding agents, with one isolated repository per company, client or life area (a "front") plus a mega-brain that reads all of them. Use when the user wants to organize their projects, clients or companies into brains, create a second brain, set up AGENTS.md-based context repositories, or add a new front to an existing brains folder.
---

# Brains setup

Builds this layout and, optionally, one private GitHub repository per folder:

```
~/Brains/
├── mega-brain/   reads every front (additionalDirectories), cross-front view
├── acme/         one front = one company, client or life area, isolated
└── personal/
```

Every front gets `AGENTS.md` (the source of truth), a `CLAUDE.md` stub that imports it, `INDEX.md`, three-layer `memory/`, `context/`, `projects/`, `.gitignore` and `.claude/settings.json`.

The work is done by `scripts/scaffold.sh`, in this skill's base directory. It only creates what is missing: it never overwrites or deletes a file.

## Steps

1. **Ask, one question at a time** (skip what the user already said):
   - Where should the brains live? Default `~/Brains`.
   - Which fronts? One per company, client or area that must not see the others' data (e.g. `acme`, `globex`, `personal`). Names are lowercase letters, digits and dashes. If the user gives display names, propose slugs and confirm them.
   - Create a **private** GitHub repository for each one? Only offer it if `gh auth status` succeeds. Repositories are named `<front>-brain`, plus `mega-brain`.

2. **Preview.** Run the script with `--dry-run` and show the user a short summary of what will be created, not the full list:

   ```bash
   bash "<skill base directory>/scripts/scaffold.sh" --root ~/Brains --fronts acme,personal --dry-run
   ```

   Add `--github` to the preview if the user chose GitHub. Add `--mega <name>` only if the user wants another name for the mega-brain.

3. **Run it** after the user confirms: the same command without `--dry-run`.

4. **Prove it worked.** List the root folder and show the `summary:` line printed by the script. With GitHub, show the `created` lines. A repository that already existed is reported as `skipped` and is never pushed to: tell the user.

5. **Tell the user what to do next** in three short bullets:
   - Open an agent session inside each front, not in the root. Each front only sees itself.
   - Each project goes in `<front>/projects/<project>/` with its own `AGENTS.md` and `PROGRESS.md`, plus a row in the front's `INDEX.md`.
   - Use `mega-brain` for questions across fronts ("status of everything").

## Adding a front later

Run the script again with only the new front: `--fronts newclient`. It creates the front and adds it to the mega-brain's `additionalDirectories` and `INDEX.md`. Nothing else changes.

## Rules

- Never pass a path the user did not confirm as `--root`.
- Never make a repository public. The script only creates private ones on purpose: brains hold client data.
- If the script exits with an error, show its message as is. Do not work around it by creating the files by hand.
