# projects-brains

A second brain for AI coding agents, organized the way consulting work actually is: **one isolated repository per company, client or life area**, plus a **mega-brain** that can read all of them.

It ships as a Claude Code plugin with three skills:

- `brains-setup` builds the structure and, if you want, a private GitHub repository for each folder;
- `new-project` and `archive-project` keep every lasting request in its own project folder, listed in the brain's index.

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
│   ├── projects/        one folder per project
│   └── .claude/rules/new-project.md   the triage rule (see below)
└── personal/
```

## Install

In Claude Code:

```
/plugin marketplace add renatomoreira/projects-brains
/plugin install projects-brains@projects-brains
```

Then ask: *"set up my brains"*, or call the skill directly with `/projects-brains:brains-setup`. It asks where to put them, which fronts you want and whether to create GitHub repositories, shows a dry run, and only writes after you confirm.

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

## Every request may become a project (1.1)

Each brain gets `.claude/rules/new-project.md`, loaded at the start of every session. Before acting, the agent classifies the request:

| Case | Test | What happens |
|---|---|---|
| Quick question | the answer fits in the chat | it just answers |
| Existing project | matches a project in the index that is not archived | it works inside that project's folder |
| New project | produces something that must outlive the conversation (files, decisions, a next step) | it proposes a name and **asks**. Only after your yes it runs `new-project` |
| Another front | belongs to another company or area | it says "this is not part of this front" and stops, without naming other fronts |

`new-project` creates `projects/<name>/` with `AGENTS.md`, `CLAUDE.md` and a progress file, adds a row to the index, commits and pushes. It follows the brain's conventions: Portuguese file names (`INDICE.md`, `PROGRESSO.md`) if the brain uses them, and a `nn-` number prefix if most projects have one.

`archive-project` marks the project as archived in the index and appends a closing note. The folder is kept.

**With Claude Projects (desktop app).** Threads in a project do not run repository hooks and do not load skills or plugins declared in the repository, so the coordinator is where the rule lives:

1. Add this plugin in **Project settings › Plugins**.
2. Paste a triage block into the project's instructions, for example:

   > Before acting on any request, classify it: quick question (answer here), existing project (send it to that project's thread), new project (propose a name and one line of scope, ask me, and only after my yes run new-project and open a thread named after the folder), or another front (say it is not part of this front and do nothing). When I say a project is over, run archive-project and tell me the thread can be closed.

Threads also load `.claude/rules/` from the repository root, so the same rule holds inside each thread.

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

It checks the generated tree, that a second run changes nothing, that your edits survive, that `--dry-run` writes nothing, that a new front is wired into the mega-brain, that projects are created and archived in English and Portuguese brains without duplicates, that the commit reaches the remote, and that bad input is rejected.

Tested with Claude Code 2.1.306 on macOS.

## License

MIT
