---
name: git-commit
description: Create clean, logical conventional git commits after reviewing and verifying repository changes.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(npm run:*), Bash(npx eslint:*)
---

## Context

- Current git status: !`git status --short --untracked-files=all`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Review the changes in the repo and prepare logical, organized, clean and descriptive git commits using conventional commits.

## Workflow

1. Inspect the working tree before staging:
   - `git status --short --untracked-files=all`
   - `git diff HEAD --stat`
   - `git diff HEAD`
   - Include untracked files explicitly; `git diff HEAD` will not show their contents.
2. Group changes by logical concern, not by file type. Prefer multiple focused conventional commits when the diff naturally separates, for example app behavior vs deployment wiring/docs.
3. Verify before committing when practical:
   - Always run `git diff --check` for whitespace/conflict-marker issues.
   - Run the most relevant project checks from repo docs/context.
   - If the full suite fails on unrelated pre-existing files, run targeted checks against changed files and report both facts exactly.
   - For builds requiring env vars, either use existing project env setup or provide explicit dummy public env values and state that the build was run with those values.
4. Respect Carlos' workflow preference: ask for authorization before creating commits. Do not push.
   - If the branch is ahead/behind its remote, report that fact during review, but do not run `git pull`, `git rebase`, or `git push` as part of commit preparation unless Carlos explicitly authorizes that separate operation.
   - Commit authorization is not push authorization.
5. After authorization, stage only the files for the intended logical commit, commit with a conventional message, then repeat for the next group.
6. Verify the final state with `git status --short`, `git log --oneline -5`, and `git diff HEAD --stat`.

## Pitfalls

- Do not claim a check passed if only a narrower command passed. Distinguish full lint/build failures from targeted verification.
- Do not omit untracked files from review or commit grouping.
- Do not perform pushes as part of this skill unless the user explicitly requests and authorizes it separately.
