---
name: archive-project
description: Archive a project in a brain - mark it archived in the brain's index and add a closing note to its progress file, then commit and push. The folder is kept. Use when the user says a project is finished, abandoned or should be closed or archived.
---

# Archive project

Marks a project as archived. Nothing is deleted.

The work is done by `scripts/archive_project.sh`, in this skill's base directory.

## Steps

1. **Confirm which project** and ask the user, in one question, why it stopped and where it ended. That answer is the closing note.
2. **Run:**

   ```bash
   bash "<skill base directory>/scripts/archive_project.sh" --brain <brain> --name <name> --reason "<closing note>"
   ```

   `--name` can be given with or without the `nn-` number prefix.
3. **Report in one line** what changed: the index status, the closing note and the branch pushed. Output `already archived` means nothing changed.
4. **In a Claude Projects coordinator**, tell the user the project's thread can now be closed.

## Rules

- Never delete the project folder.
- If the script exits with an error, show its message. Do not edit the files by hand.
