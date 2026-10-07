# Issue tracker: Brain Portal Tasks

Used by Matt Pocock's skills ("Other" tracker).

| Field | Value |
| --- | --- |
| Tracker | Brain Portal Tasks, via the `portal-tasks` MCP server |
| Landing | signed commits on `main` with `git-commit`; links applied with `rotz`. No push without an explicit request |

## When a skill says "fetch the relevant ticket"

Read the TODO with `tasks_get`. The ticket content lives in
`.scratch/<todo-id>/ticket.md`.

## When a skill says "publish to the issue tracker"

Capture a TODO with `tasks_capture` and write the ticket to
`.scratch/<todo-id>/ticket.md`.
