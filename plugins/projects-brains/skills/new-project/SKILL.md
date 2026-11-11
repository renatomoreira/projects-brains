---
name: new-project
description: Create a new project folder inside a brain (projects/<name>/ with AGENTS.md, CLAUDE.md and PROGRESS.md, plus a row in the brain's index), then commit and push. Use only after the user has said yes to turning a request into a new project, or when the user explicitly asks to create a project in a brain.
---

# New project

Creates `projects/<name>/` in the current brain and lists it in the brain's index. Follows the brain's own conventions: Portuguese file names (`INDICE.md`, `PROGRESSO.md`) when the brain uses them, and a `nn-` number prefix when most projects have one. It never overwrites anything.

The work is done by `scripts/new_project.sh`, in this skill's base directory.

## Steps

1. **Make sure the user said yes.** If you are here because you classified a request as a new project, you must already have asked and received an explicit yes. If not, ask now and stop.
2. **Collect:**
   - `--brain`: the brain's root folder, the one with `INDEX.md` or `INDICE.md`. Usually the repository root of the current session.
   - `--name`: lowercase letters, digits and dashes, without a number prefix (the script adds one if the brain uses them).
   - `--summary`: one line of scope, in the brain's language.
3. **Run:**

   ```bash
   bash "<skill base directory>/scripts/new_project.sh" --brain <brain> --name <name> --summary "<one line>"
   ```

4. **Read the output and report in two lines:**
   - `created`: the folder. `pushed`: the branch.
   - `exists`: the project was already there, nothing changed. Treat the request as belonging to that existing project.
   - A warning that the commit is not on the default branch: if `gh` is available, open a pull request (`gh pr create --fill`) and give the user the link. Otherwise tell the user to merge, because new sessions only see the project after that.
5. **Hand off:** in a Claude Projects coordinator, open a new thread named after the project folder and start the work there. In a normal session, continue inside `projects/<folder>/` and keep its progress file updated.

## Rules

- Never create a project the user did not confirm.
- Never create a project for a request that belongs to another front: say it is not part of this front and stop.
- If the script exits with an error, show its message. Do not create the files by hand.
