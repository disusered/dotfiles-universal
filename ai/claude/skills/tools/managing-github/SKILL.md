---
name: managing-github
description: Creates and manages GitHub pull requests and issues via gh CLI. Use when creating PRs, commenting on issues, reviewing code, or performing GitHub operations. CRITICAL - Always confirms gitflow branch targets before PR creation and requests permission for write operations.
allowed-tools: Bash
---

# Managing GitHub

Command-line interface for GitHub issues and pull requests.

## Critical Rules

**PR Creation:**
- `gh pr create` requires user permission
- Assume code is already committed - don't run `git commit` or `git push`
- Confirm gitflow branch targets before creating PR

**Gitflow Branch Targets:**
```
hotfix/*    → main
feature/*   → develop
release/*   → main
bugfix/*    → develop
claude/*    → ask user
```

**Destructive Operations:**
- Never use `git rebase`, `git push --force`, or `git reset --hard` without explicit permission

**Output Format:**
- No footers, signatures, or tool attribution in PR descriptions

## Quick Start

```bash
# View issues
gh issue list --limit 10

# View PR details
gh pr view 456 --comments

# Create PR (requires permission, confirms branch target)
gh pr create --title "Fix bug" --body "Description"

# Comment on issue (requires permission)
gh issue comment 123 --body "Update"
```

## When to Use

- Creating pull requests
- Managing issues (create, comment, view)
- Reviewing code
- Viewing PR/issue details
- **NOT for**: git operations (use git directly)

## Reference Documentation

For detailed command reference and workflows:
- [PR-WORKFLOW.md](PR-WORKFLOW.md) - Pull request workflow with branch targeting checklist
- [ISSUES.md](ISSUES.md) - Issue operations reference
- [REFERENCE.md](REFERENCE.md) - Complete command reference

## Common Operations

### Issues

```bash
# List issues
gh issue list --state all --label bug

# View issue with comments
gh issue view 123 --comments

# Create issue (requires permission)
gh issue create --title "Bug" --body "Description"

# Comment (requires permission)
gh issue comment 123 --body "Fixed in PR #456"
```

### Pull Requests

```bash
# List PRs
gh pr list --state open

# View PR
gh pr view 456 --comments

# Create PR (follow PR-WORKFLOW.md)
gh pr create --title "Fix" --body-file pr.md --base develop

# Review PR (requires permission)
gh pr review 456 --approve --body "LGTM"
```

## Authentication

```bash
# Check status
gh auth status

# Login if needed
gh auth login
```
