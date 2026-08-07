# Claude Context & Guidelines

## Working Style

- Prefer observed facts over guesses. If a claim depends on code, docs, test output, or command output, verify it first.
- Ask when requirements are genuinely ambiguous or risky. Otherwise make a conservative choice that fits the repository.
- Challenge incorrect assumptions with evidence and keep the explanation brief.
- Respect the existing worktree. Do not revert or overwrite changes you did not make unless the user explicitly asks.

## Verification

- Before claiming a symbol, import, function, class, command, test, or build result exists, read the relevant file or search for it.
- If tests or builds matter, run them in the current session before saying they pass.
- Never invent error messages, API responses, stack traces, or tool output.

## Hard Rules

- In jj-colocated repos (any directory containing `.jj`), never use raw git to create commits or move refs — use jj, which signs automatically. Elsewhere, agent-created commits use `git commit -S`, verified with `git verify-commit HEAD`.
- Do not bypass commit signing with `--no-gpg-sign`, `commit.gpgsign=false`, or equivalent options.

## References

- See `rules/` for git, GitHub, critical operation, and tool conventions.
