---
name: cfg-project-tasks
description: Discover and run unfamiliar, parameterized, multi-process, environment-sensitive, containerized, or project-specific workflows through cfg. Do not use cfg to wrap an exact user-supplied command or an obvious standard one-step command.
---

# CFG Project Tasks

Use cfg when it removes real uncertainty or coordinates a project process set. Run exact user-supplied commands and obvious standard one-step commands such as `npm run dev` or `cargo test` directly.

## Workflow

1. If the user supplied an exact command, or the repository exposes an obvious standard one-step command, run it directly without consulting cfg.
2. For Procfile or Compose project lifecycle, use `cfg up` and `cfg down`. Add explicit environment files with repeated `--env-file PATH` when required.
3. When command selection, parameters, working directory, environment, or container context is genuinely uncertain, run `cfg run --list --json` from the relevant project directory.
4. Read the returned `project_root`, `default_task`, task names, descriptions, command templates, and parameter schemas, then choose an exact task. Supply declared values with repeated `--param KEY=VALUE`; put task-specific extra arguments after `--`.
5. Use bare `cfg run` only when the user's intent is the project's configured/default action and the returned `default_task` is non-null. If it is null, choose an exact listed task instead of guessing.
6. Preserve the command's exit status and report the actual output. Do not claim success when the task failed.

If cfg is unavailable or returns no matching tasks, fall back to repository instructions and manifests. Do not invent a cfg task name or add task configuration unless the user asks.

## Examples

```sh
cfg up --procfile --env-file .env.local
cfg down --compose
cfg run --list --json
cfg run "docker compose exec" --param service=web --param command="bin/rails test"
```
