---
name: gh
description: Use GitHub CLI to interact with issues and pull requests (view, create, comment). Load this when you need to perform GitHub operations.
allowed-tools: Bash
---

# GitHub CLI Reference

Command-line interface for GitHub issues and pull requests.

## Basic Syntax

```bash
gh [COMMAND] [SUBCOMMAND] [OPTIONS] [ARGS]
```

## Issues

### List issues

```bash
gh issue list [OPTIONS]

# Options:
#   --limit INT         Maximum number of issues to fetch (default: 30)
#   --state STRING      Filter by state: open, closed, all (default: open)
#   --label STRING      Filter by label
#   --assignee STRING   Filter by assignee
#   --repo STRING       Repository (format: owner/repo)

# Examples:
gh issue list --limit 10
gh issue list --state all --label bug
gh issue list --assignee @me
```

### View issue

```bash
gh issue view <issue-number> [OPTIONS]

# Options:
#   --web              Open in web browser
#   --comments         Include comments
#   --repo STRING      Repository (if not in current repo)

# Examples:
gh issue view 123
gh issue view 123 --comments
gh issue view 123 --repo owner/repo
```

### Create issue

```bash
gh issue create [OPTIONS]

# Options:
#   --title STRING      Issue title (required)
#   --body STRING       Issue body
#   --body-file PATH    Read body from file
#   --label STRING      Add label (can be repeated)
#   --assignee STRING   Assign to user
#   --repo STRING       Repository (if not in current repo)

# Examples:
gh issue create --title "Fix bug" --body "Description here"
gh issue create --title "Feature request" --body-file description.md
```

### Comment on issue

```bash
gh issue comment <issue-number> [OPTIONS]

# Options:
#   --body STRING       Comment body (required if not using --body-file)
#   --body-file PATH    Read body from file
#   --repo STRING       Repository (if not in current repo)

# Examples:
gh issue comment 123 --body "Fixed in PR #456"
gh issue comment 123 --body-file update.md
```

### Edit issue

```bash
gh issue edit <issue-number> [OPTIONS]

# Options:
#   --add-label STRING      Add label
#   --remove-label STRING   Remove label
#   --add-assignee STRING   Add assignee
#   --remove-assignee STRING Remove assignee
#   --title STRING          Update title
#   --body STRING           Update body

# Examples:
gh issue edit 123 --add-label bug --add-label priority
gh issue edit 123 --title "New title"
```

## Pull Requests

### List PRs

```bash
gh pr list [OPTIONS]

# Options:
#   --limit INT         Maximum number of PRs to fetch
#   --state STRING      Filter by state: open, closed, merged, all
#   --label STRING      Filter by label
#   --repo STRING       Repository (if not in current repo)

# Examples:
gh pr list --limit 10
gh pr list --state merged
```

### View PR

```bash
gh pr view <pr-number> [OPTIONS]

# Options:
#   --web              Open in web browser
#   --comments         Include comments
#   --repo STRING      Repository (if not in current repo)

# Examples:
gh pr view 456
gh pr view 456 --comments --web
```

### Create PR

```bash
gh pr create [OPTIONS]

# Options:
#   --title STRING      PR title (required)
#   --body STRING       PR body
#   --body-file PATH    Read body from file
#   --base STRING       Base branch (default: repository default branch)
#   --head STRING       Head branch (default: current branch)
#   --draft             Create as draft
#   --label STRING      Add label (can be repeated)
#   --assignee STRING   Assign to user
#   --repo STRING       Repository (if not in current repo)

# Examples:
gh pr create --title "Fix OAuth bug" --body "See work log"
gh pr create --title "Add feature" --body-file pr-description.md
gh pr create --title "Draft PR" --draft --base develop
```

### Comment on PR

```bash
gh pr comment <pr-number> [OPTIONS]

# Options:
#   --body STRING       Comment body (required if not using --body-file)
#   --body-file PATH    Read body from file
#   --repo STRING       Repository (if not in current repo)

# Examples:
gh pr comment 456 --body "LGTM"
gh pr comment 456 --body-file review.md
```

### Review PR

```bash
gh pr review <pr-number> [OPTIONS]

# Options:
#   --approve           Approve PR
#   --request-changes   Request changes
#   --comment           Comment-only review
#   --body STRING       Review comment
#   --body-file PATH    Read body from file

# Examples:
gh pr review 456 --approve --body "Looks good!"
gh pr review 456 --request-changes --body "Please address comments"
gh pr review 456 --comment --body-file detailed-review.md
```

### Merge PR

```bash
gh pr merge <pr-number> [OPTIONS]

# Options:
#   --merge            Create merge commit (default)
#   --squash           Squash and merge
#   --rebase           Rebase and merge
#   --delete-branch    Delete branch after merge

# Examples:
gh pr merge 456 --squash --delete-branch
gh pr merge 456 --merge
```

## Common Patterns

### Create PR with description from file

```bash
# Generate PR description (via work-journal skill)
# Then create PR
gh pr create --title "Fix: OAuth token validation" --body-file /tmp/pr-description.md
```

### Post work log reference to issue

```bash
# After creating work log in dev/active/
gh issue comment 123 --body "Work log: dev/active/fix-oauth-token.md"
```

### Check issue details before starting work

```bash
# View issue and all comments
gh issue view 123 --comments
```

### Create draft PR early

```bash
# Create draft PR to get early feedback
gh pr create --title "WIP: OAuth refactor" --draft --body "Early draft for feedback"
```

## Getting Help

Use `--help` on any command or subcommand:

```bash
gh --help
gh issue --help
gh pr --help
gh pr create --help
```

## Authentication

Ensure you're authenticated:

```bash
# Check authentication status
gh auth status

# Login if needed
gh auth login
```
