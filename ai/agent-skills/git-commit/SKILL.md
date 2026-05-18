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
3. Group changes by logical concern, not by file type. Prefer multiple focused conventional commits when the diff naturally separates.
4. Verify before committing when practical:
   - Always run `git diff --check`.
   - Run the most relevant project checks from repo docs or task context.
   - If a full suite fails on unrelated pre-existing files, run targeted checks against changed files and report both facts exactly.
5. Check recent commit style before choosing commit messages.
6. If the user explicitly asked to commit, stage only the intended files and commit. Otherwise, prepare the commit plan and ask before creating commits.
7. Do not pull, rebase, push, amend, or otherwise rewrite history unless the user explicitly asks for that separate operation.
8. After committing, verify with `git status --short`, `git log --oneline -5`, and `git diff HEAD --stat`.

## Pitfalls

- Do not omit untracked files from review or commit grouping.
- Do not claim a check passed if only a narrower command passed.
- Do not mix unrelated changes into one commit for convenience.
- Do not push as part of this skill unless the user explicitly requests it.
