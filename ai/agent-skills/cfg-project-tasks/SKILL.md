---
name: cfg-project-tasks
description: Discover project workflows and manage long-lived development services through cfg. Use for workspace/process lifecycle, output inspection, restart/stop, and unfamiliar or parameterized tasks. Run exact one-shot commands directly.
---

# CFG Project Tasks

Use cfg to keep delegated development services discoverable and manageable.
Run exact one-shot commands such as `cargo test` directly.

## Development services

1. Inspect `cfg process list --json` from the project or workspace. Use `--all`
   when locating an existing process outside that scope.
2. Read the intended ID with `cfg process read ID --json`. Check process state,
   exit status, attempt and output limits before diagnosing it.
3. After changes, use the service's existing reload mechanism. If it needs a
   restart, use `cfg process restart ID --json`; use `stop` to leave it stopped
   and inspectable. Verify the updated behavior at its normal address before
   reporting completion.
4. For a new workspace, use `cfg up --workspace`; for a Procfile or Compose
   process set, use `cfg up`, selecting a backend when discovery is ambiguous.
   Outside Kitty, bootstrap with `cfg up --workspace --kitty-socket SOCKET
   --source-window ID` (omit `--workspace` for a project process set). Select the
   existing session's socket and exact pane ID from its Kitty inventory, using
   `kitty @ --to SOCKET ls` when needed. This works with an empty process registry
   and copies the selected pane's recorded environment. A managed process ID is
   not required. Keep these live destination values in the handoff.
   Stop the set through its corresponding `cfg down --kitty-socket SOCKET`.
5. For an additional long-lived command, use
   `cfg process start --name NAME -- COMMAND...`. Select a destination with
   `--into ID` if multiple Kitty sessions exist. Supply repeated `--env-file`
   paths when needed; base environment comes from Kitty's recorded source pane.

Keep the managed ID in the work handoff. A successful restart request or running
PID does not establish application readiness. Kitty history is bounded combined
terminal text; inspect truncation and attempt-boundary fields. Old panes acquire
control endpoints after their normal restart. A missing endpoint is not a reason
to silently launch a duplicate service or change its port.

Unix socket access can be denied by an agent sandbox. On `Operation not permitted`,
retry the same cfg command with the harness's supported escalation. Entries under
`unavailable` report failed inspection; they do not establish that a service died.
An `exited` launcher with code 0 still needs output and application checks before
claiming readiness.

## Task discovery

1. When command selection, parameters, cwd, environment or container context is
   uncertain, run `cfg run --list --json` from the relevant project.
2. Read the returned project root, default task, exact names and parameter
   schemas. Supply declared values with repeated `--param KEY=VALUE`; place extra
   arguments after `--`.
3. Use bare `cfg run` only for the configured/default action when `default_task`
   is non-null. Run an exact task directly for one-shot work, or place
   `cfg run "exact task name"` after `cfg process start ... --` for a service.
4. Preserve exit status and report failures. If no matching task exists, consult
   repository instructions and manifests instead of inventing a task.

At a workspace root, bare `cfg up/down` auto-selects `.cfg/workspace.toml`.
From a nested repository, use `--workspace` explicitly. Foreground `cfg run`
remains a one-shot interface; it does not register a persistent service.
