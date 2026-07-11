---
name: cfg-project-tasks
description: Discover and run project build, test, development, database, container, and maintenance tasks through cfg. Use before guessing or manually composing project commands when cfg is available, especially when an agent needs the repository's intended command or parameters.
---

# CFG Project Tasks

Use cfg's live Overseer-style task catalog and resolved project default as the source of truth for project commands.

## Workflow

1. Run `cfg run --list --json` from the relevant project directory.
2. Read the returned `project_root`, `default_task`, task names, descriptions, command templates, and parameter schemas.
3. When the user's intent is the project's normal/default run action and `default_task` is non-null, invoke bare `cfg run`. In non-interactive sessions it executes that exact resolved task without opening fzf.
4. For any more specific intent, choose an exact returned task name and run it with `cfg run "<task name>"`. Supply declared values with repeated `--param KEY=VALUE`; put task-specific extra arguments after `--`.
5. If `default_task` is null, do not guess what bare `cfg run` should mean; choose an exact listed task or report that no default is available.
6. Preserve the command's exit status and report the actual output. Do not claim success when the task failed.

If cfg is unavailable or returns no matching tasks, fall back to repository instructions and manifests. Do not invent a cfg task name or add task configuration unless the user asks.

## Examples

```sh
cfg run --list --json
cfg run
cfg run "cargo test"
cfg run "docker compose exec" --param service=web --param command="bin/rails test"
```
