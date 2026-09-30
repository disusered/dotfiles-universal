# Issue tracker: Brain Portal Tasks (owner)

Used by the `delegated-work` protocol and Matt Pocock's skills ("Other" tracker).

## Workspace configuration

| Field | Value |
| --- | --- |
| Tracker | Brain Portal Tasks, via the `portal-tasks` MCP server |
| AC owner | the user, through the PM role |
| Roles the agent may take | all, one per context |
| Release target | signed commits on `main` with `git-commit`; links applied with `rotz`. No push without an explicit request |

## When a skill says "fetch the relevant ticket"

Read the TODO with `tasks_get`. Until Portal TODOs carry a body, the ticket
content lives in `.scratch/<todo-id>/ticket.md`.

## When a skill says "publish to the issue tracker"

Capture a TODO with `tasks_capture` and write the ticket to
`.scratch/<todo-id>/ticket.md`.

## Item state

Until Portal TODOs carry a work stage, the stage is the first line of
`.scratch/<todo-id>/status`.
