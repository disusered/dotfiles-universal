---
name: git-commit
description: Use when the user asks Codex to prepare or create git commits from current repository changes, including explicit $git-commit requests, "commit these changes", packaging work into logical commits, or conventional commit cleanup.
---

# Git Commit

Prepare clean, logical git commits from the current repository state.

## Workflow

1. Inspect the working tree before staging:
   - `git status --short --untracked-files=all`
   - `git diff HEAD --stat`
   - `git diff HEAD`
   - `git branch --show-current`
   - `git log --oneline -10`
2. Include untracked files explicitly; `git diff HEAD` does not show their contents.
3. Before staging, check for `.jj` at the repository root. In jj-colocated repositories, use the documented `jj` workflow to create and verify signed commits; never use raw git to create commits or move refs. The git mutation and verification steps below apply only outside those repositories.
   Group changes by logical concern, not by file type. Prefer multiple focused commits when the diff naturally separates.
4. Verify before committing when practical:
   - Always run `git diff --check`.
   - Run the most relevant project checks from repo docs or task context.
   - If a full suite fails on unrelated pre-existing files, run targeted checks against changed files and report both facts exactly.
5. Follow repository instructions and recent commit style. Use Conventional Commits only when neither establishes another style.
6. If the user explicitly asked to commit, stage only the intended files and create signed commits with `git commit -S ...`. Verify each new commit immediately with `git verify-commit HEAD`. Otherwise, prepare the commit plan and ask before creating commits.
7. Do not pull, rebase, push, amend, or otherwise rewrite history unless the user explicitly asks for that separate operation.
8. After committing, inspect `git status --short`, `git log --oneline -5`, and `git diff HEAD --stat`. Report the verified commits and any remaining changes.

## Pitfalls

- Do not omit untracked files from review or commit grouping.
- Do not claim a check passed if only a narrower command passed.
- Do not mix unrelated changes into one commit for convenience.
- Do not push as part of this skill unless the user explicitly requests it.
- Preserve the configured signing backend, including SSH signing through 1Password when configured. `git commit -S` does not require switching to GPG.
- If signing fails, inspect the exact error and apply the shared tool-failure recovery rules. When sandbox access to the configured signer is blocked, request supported escalation for the same operation. Before retrying a commit, inspect repository state to avoid duplicating a commit that succeeded before verification failed.
- Never request or export private keys, change the signing backend, or use `--no-gpg-sign`, `commit.gpgsign=false`, or another signing bypass to work around access restrictions. A real denial or persistent failure stops the affected operation; report the exact failure and continue independent authorized work. Do not report the commit task complete until signing verification succeeds.
