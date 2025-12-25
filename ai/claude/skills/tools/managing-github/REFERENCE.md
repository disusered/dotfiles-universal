# GitHub CLI Complete Reference

Complete command reference for gh CLI operations.

## Contents

- [Pull Requests](#pull-requests)
  - [List PRs](#list-prs)
  - [View PR](#view-pr)
  - [Create PR](#create-pr)
  - [Comment on PR](#comment-on-pr)
  - [Review PR](#review-pr)
  - [Merge PR](#merge-pr)
  - [Close/Reopen PR](#close-reopen-pr)
- [Issue Operations](#issue-operations)
- [Common Patterns](#common-patterns)
- [Help and Documentation](#help-and-documentation)

## Pull Requests

### List PRs

```bash
gh pr list [OPTIONS]
```

**Options:**
- `--limit INT` - Maximum number of PRs to fetch
- `--state STRING` - Filter by state: open, closed, merged, all
- `--label STRING` - Filter by label
- `--author STRING` - Filter by author
- `--assignee STRING` - Filter by assignee
- `--base STRING` - Filter by base branch
- `--head STRING` - Filter by head branch
- `--repo STRING` - Repository (if not in current repo)

**Examples:**

```bash
# List open PRs
gh pr list

# List all PRs including merged
gh pr list --state all

# List my PRs
gh pr list --author @me

# List PRs to develop branch
gh pr list --base develop

# Limit results
gh pr list --limit 5
```

### View PR

```bash
gh pr view <pr-number> [OPTIONS]
```

**Options:**
- `--web` - Open in web browser
- `--comments` - Include comments in output
- `--repo STRING` - Repository (if not in current repo)

**Examples:**

```bash
# View PR details
gh pr view 456

# View with comments
gh pr view 456 --comments

# Open in browser
gh pr view 456 --web

# View from another repo
gh pr view 456 --repo owner/repo
```

### Create PR

**Requires user permission and branch targeting confirmation**

See [PR-WORKFLOW.md](PR-WORKFLOW.md) for complete workflow.

```bash
gh pr create [OPTIONS]
```

**Options:**
- `--title STRING` - PR title (required)
- `--body STRING` - PR body
- `--body-file PATH` - Read body from file
- `--base STRING` - Base branch (default: repository default branch)
- `--head STRING` - Head branch (default: current branch)
- `--draft` - Create as draft PR
- `--label STRING` - Add label (can be repeated)
- `--assignee STRING` - Assign to user
- `--reviewer STRING` - Request review from user
- `--milestone STRING` - Add to milestone
- `--repo STRING` - Repository (if not in current repo)

**Examples:**

```bash
# Basic PR
gh pr create --title "Fix OAuth bug" --body "Description" --base develop

# PR from file
gh pr create --title "Add feature" --body-file pr-description.md --base develop

# Draft PR
gh pr create --title "WIP: Refactor" --draft --base develop

# With labels and reviewers
gh pr create --title "Fix" --base develop --label bug --reviewer username

# Full example
gh pr create \
  --title "Fix OAuth token validation" \
  --body-file /tmp/pr-description.md \
  --base develop \
  --label bug \
  --label security \
  --reviewer alice --reviewer bob \
  --assignee @me
```

### Comment on PR

**Requires user permission**

```bash
gh pr comment <pr-number> [OPTIONS]
```

**Options:**
- `--body STRING` - Comment body (required if not using --body-file)
- `--body-file PATH` - Read body from file
- `--repo STRING` - Repository (if not in current repo)

**Examples:**

```bash
# Simple comment
gh pr comment 456 --body "LGTM"

# Comment from file
gh pr comment 456 --body-file review-notes.md

# Multi-line comment
gh pr comment 456 --body "$(cat <<'EOF'
Changes look good!

Minor suggestions:
- Add tests for edge case
- Update documentation
EOF
)"
```

### Review PR

**Requires user permission**

```bash
gh pr review <pr-number> [OPTIONS]
```

**Options:**
- `--approve` - Approve PR
- `--request-changes` - Request changes
- `--comment` - Comment-only review (no approval/rejection)
- `--body STRING` - Review comment
- `--body-file PATH` - Read review body from file

**Examples:**

```bash
# Approve
gh pr review 456 --approve

# Approve with comment
gh pr review 456 --approve --body "Looks good, merging!"

# Request changes
gh pr review 456 --request-changes --body "Please address the comments"

# Comment-only review
gh pr review 456 --comment --body "Good work, a few minor suggestions"

# Review from file
gh pr review 456 --approve --body-file detailed-review.md
```

### Merge PR

**Requires user permission**

```bash
gh pr merge <pr-number> [OPTIONS]
```

**Options:**
- `--merge` - Create merge commit (default)
- `--squash` - Squash and merge
- `--rebase` - Rebase and merge
- `--delete-branch` - Delete head branch after merge
- `--auto` - Automatically merge when checks pass

**Examples:**

```bash
# Merge with merge commit
gh pr merge 456 --merge

# Squash and merge
gh pr merge 456 --squash --delete-branch

# Rebase and merge
gh pr merge 456 --rebase

# Auto-merge when ready
gh pr merge 456 --auto --squash
```

### Close/Reopen PR

**Requires user permission**

```bash
# Close PR without merging
gh pr close <pr-number>

# Reopen closed PR
gh pr reopen <pr-number>
```

**Examples:**

```bash
# Close PR
gh pr close 456

# Close with comment
gh pr comment 456 --body "Closing as duplicate" && gh pr close 456

# Reopen PR
gh pr reopen 456
```

## Issue Operations

See [ISSUES.md](ISSUES.md) for complete issue operations reference.

## Common Patterns

### Create PR with Work Log

```bash
# 1. Generate PR description using work-journal skill
# 2. Save to temp file
# 3. Follow PR workflow
gh pr create --title "Fix: OAuth token validation" --body-file /tmp/pr-description.md --base develop
```

### Draft PR for Early Feedback

```bash
# Create draft early
gh pr create --title "WIP: OAuth refactor" --draft --base develop --body "Early draft for architecture review"

# Mark ready when done
gh pr ready 456
```

### Update PR After Review

```bash
# Comment on changes
gh pr comment 456 --body "Updated per review comments"

# Re-request review
gh pr review 456 --comment --body "Ready for re-review"
```

### Link PR to Issue

```bash
# In PR body, use keywords:
# "Fixes #123" or "Closes #123" or "Resolves #123"
# GitHub will auto-close issue when PR merges

# Or comment on issue
gh issue comment 123 --body "Fixed in PR #456"
```

### Check CI Status

```bash
# View PR with checks
gh pr view 456

# View detailed checks
gh pr checks 456

# Watch checks in real-time
gh pr checks 456 --watch
```

## Help and Documentation

```bash
# General help
gh --help

# Issue help
gh issue --help

# PR help
gh pr --help

# Specific command help
gh pr create --help
gh issue comment --help

# Manual pages
man gh
man gh-pr
man gh-issue
```

## Authentication

```bash
# Check authentication status
gh auth status

# Login (interactive)
gh auth login

# Login with token
gh auth login --with-token < token.txt

# Logout
gh auth logout

# List authenticated accounts
gh auth status
```

## Repository Context

```bash
# View current repo
gh repo view

# Set default repo
gh repo set-default owner/repo

# Clone repo
gh repo clone owner/repo
```

## Tips and Best Practices

### Use Body Files for Long Content

```bash
# Instead of long --body strings, use files
gh pr create --title "Title" --body-file description.md
```

### Combine with Git

```bash
# Check branch before creating PR
git branch --show-current

# Ensure changes are pushed
git push origin HEAD

# Then create PR
gh pr create --title "Title" --body "Description" --base develop
```

### Use JSON Output for Scripting

```bash
# Get PR data as JSON
gh pr view 456 --json number,title,state,author

# List as JSON
gh pr list --json number,title,author --limit 10

# Pipe to jq
gh pr list --json number,title --limit 10 | jq '.[] | select(.title | contains("bug"))'
```

### Check Before Write Operations

```bash
# View before commenting
gh pr view 456

# List before creating
gh pr list --base develop

# Always request permission for writes
```
