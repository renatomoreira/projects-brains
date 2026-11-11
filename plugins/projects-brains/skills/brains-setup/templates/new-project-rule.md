# Every request may become a project

Before acting on a request, classify it:

| Case | Test | What to do |
|---|---|---|
| Quick question | The answer fits in the chat; nothing needs to survive the conversation | Answer. Do not ask anything about projects |
| Existing project | It matches a project in the index whose status is not archived | Say which one and work inside its folder. Update its progress file before ending |
| New project | It produces something that must survive the conversation (files, decisions, a next step) and fits no existing project | Propose a folder name and one line of scope, then **ask**. Only after an explicit yes, use the `new-project` skill |
| Another front | It belongs to another company, client or area | Say only "this is not part of this front" and do not do it. Never name or guess other fronts |

- Unsure between existing and new: ask which.
- Never create a project folder without the user's yes.
- When the user says a project is over: use the `archive-project` skill. It marks it archived in the index; the folder is kept.
