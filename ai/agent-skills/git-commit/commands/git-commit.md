---
name: git-commit
description: Create a git commit
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit -S:*), Bash(git verify-commit:*)
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Review the changes in the repo and prepare logical, organized, clean and descriptive git commits using conventional commits.

Every commit must be GPG-signed with `git commit -S ...`. Never use `--no-gpg-sign`, `commit.gpgsign=false`, or any other signing bypass. After committing, run `git verify-commit HEAD`; if verification fails, the commit task is not complete.
