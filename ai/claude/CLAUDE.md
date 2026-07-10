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
- Use `rg` for text/file search when available.

## Hard Rules

- Never run `tofu`, `terraform`, `tofu init`, `tofu plan`, or `tofu apply` locally.
- Do not run `git pull`, `git pull --rebase`, or `git push` as routine session cleanup.
- All agent-created commits must be signed with `git commit -S`, then verified with `git verify-commit HEAD`.
- Do not bypass commit signing with `--no-gpg-sign`, `commit.gpgsign=false`, or equivalent options.
- Require explicit permission for destructive git operations, force pushes, branch deletion, and PR/issue write operations.

## References

- See `rules/` for git, GitHub, critical operation, and tool conventions.
