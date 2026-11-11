# projects-brains

A second brain for AI coding agents, organized the way consulting work actually is: **one isolated repository per company, client or life area**, plus a **mega-brain** that can read all of them.

It ships as a Claude Code plugin with one skill, `brains-setup`, that builds the structure for you and, if you want, creates a private GitHub repository for each folder.

```
~/Brains/
├── mega-brain/          cross-front view: reads every front
│   ├── AGENTS.md
│   ├── INDEX.md         one row per front
│   ├── PROGRESS.md
│   ├── knowledge/       lessons that apply to more than one front
│   └── .claude/settings.json   additionalDirectories: ../acme, ../personal
├── acme/                one front = one company, client or area
│   ├── AGENTS.md        source of truth for any agent
│   ├── CLAUDE.md        @AGENTS.md + @memory/MEMORY.md
│   ├── INDEX.md         projects, status, where each thing lives
│   ├── memory/          MEMORY.md (hot), topics/ (warm), sessions/ (cold)
│   ├── context/         stable background: people, systems, glossary
│   └── projects/        one folder per project
└── personal/
```

## Install

In Claude Code:

```
/plugin marketplace add renatomoreira/projects-brains
/plugin install projects-brains@projects-brains
```

Then ask: *"set up my brains"*, or call the skill directly with `/brains-setup`. It asks where to put them, which fronts you want and whether to create GitHub repositories, shows a dry run, and only writes after you confirm.

You can also run the script without Claude:

```bash
bash plugins/projects-brains/skills/brains-setup/scripts/scaffold.sh \
  --root ~/Brains --fronts acme,personal --dry-run
```

| Option | What it does |
|---|---|
| `--root DIR` | where the brains live (required) |
| `--fronts a,b,c` | front names: lowercase letters, digits and dashes (required) |
| `--mega NAME` | name of the mega-brain folder (default `mega-brain`) |
| `--github` | `git init` each folder and create a **private** repository: `<front>-brain` and `mega-brain`. Needs `gh` logged in |
| `--dry-run` | print what would happen and write nothing |

Requirements: `bash` and `git`. `gh` only for `--github`. `python3` only when adding a front to an existing mega-brain.

## Why it is built this way

**One repository per front.** Agents load instruction files from the folder they run in and from every parent folder. Put two clients under one repository and the agent reads both. A repository per company keeps one client's data out of another client's sessions, and lets you share or archive a front on its own.

**A mega-brain that reads, but is not read.** The mega-brain lists the fronts in `additionalDirectories` (`.claude/settings.json`). That gives it file access to every front **without** loading their instruction files, so "what is the status of everything?" costs only the files the question needs. No front can see the mega-brain or the other fronts.

**`AGENTS.md` is the source of truth, `CLAUDE.md` is a stub.** `AGENTS.md` is read by most coding agents. Claude Code reads `CLAUDE.md`, so each one contains only `@AGENTS.md` and `@memory/MEMORY.md`. You write the rules once and every agent follows them.

**Memory in three layers, inside git.** An agent's built-in memory usually lives on one machine and does not travel. Here memory is versioned with the repository:
- `memory/MEMORY.md`: always loaded, under 200 lines, one line per fact or pointer;
- `memory/topics/`: one subject per file, opened only when a line in `MEMORY.md` points to it;
- `memory/sessions/`: dated summaries, never loaded, searched when needed.

**Code does not live in a brain.** A project's `AGENTS.md` points to the official remote. To work locally, clone into `projects/<project>/repo/`, which is ignored by git, and delete it when you are done. Brains stay small and never duplicate a codebase.

**Files over chat.** Every rule in the generated `AGENTS.md` pushes the agent to write state to files: decisions, progress and lessons. A new session picks up where the last one stopped.

## Safety

- The script **never overwrites or deletes** a file. Run it again and it only creates what is missing; your edits stay.
- Adding a front later (`--fronts newclient`) appends it to the mega-brain's `additionalDirectories` and `INDEX.md`. Those are the only edits it makes to existing files.
- GitHub repositories are **always private**. If a repository with the same name already exists, it is skipped and nothing is pushed to it.
- Each `.claude/settings.json` denies the agent read access to `.env` files.

## Using it day to day

1. Open your agent session **inside a front** (`~/Brains/acme`), never in `~/Brains`.
2. Create each project as `projects/<project>/` with an `AGENTS.md` (what it is, where the code lives) and a `PROGRESS.md` (where it stopped, what blocks it, next step). Add a row to the front's `INDEX.md`.
3. Before closing a session, ask the agent to update `PROGRESS.md` and, if something durable was learned, `memory/`.
4. Open the mega-brain for questions across fronts.

## Tests

```bash
bash tests/run.sh
```

It checks the generated tree, that a second run changes nothing, that your edits survive, that `--dry-run` writes nothing, that a new front is wired into the mega-brain, and that bad input is rejected.

Tested with Claude Code 2.1.306 on macOS.

## License

MIT
