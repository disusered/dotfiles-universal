# GitHub Issues Reference

Complete reference for issue operations.

## List Issues

```bash
gh issue list [OPTIONS]
```

### Options

- `--limit INT` - Maximum number of issues to fetch (default: 30)
- `--state STRING` - Filter by state: open, closed, all (default: open)
- `--label STRING` - Filter by label
- `--assignee STRING` - Filter by assignee
- `--repo STRING` - Repository (format: owner/repo)

### Examples

```bash
# List open issues
gh issue list

# List all issues (including closed)
gh issue list --state all

# List bugs
gh issue list --label bug

# List issues assigned to me
gh issue list --assignee @me

# List issues from specific repo
gh issue list --repo owner/repo

# Combine filters
gh issue list --state all --label bug --limit 20
```

## View Issue

```bash
gh issue view <issue-number> [OPTIONS]
```

### Options

- `--web` - Open in web browser
- `--comments` - Include comments in output
- `--repo STRING` - Repository (if not in current repo)

### Examples

```bash
# View issue details
gh issue view 123

# View with all comments
gh issue view 123 --comments

# Open in browser
gh issue view 123 --web

# View issue from another repo
gh issue view 123 --repo owner/repo
```

## Create Issue

**Requires user permission**

```bash
gh issue create [OPTIONS]
```

### Options

- `--title STRING` - Issue title (required)
- `--body STRING` - Issue body
- `--body-file PATH` - Read body from file
- `--label STRING` - Add label (can be repeated)
- `--assignee STRING` - Assign to user
- `--milestone STRING` - Add to milestone
- `--repo STRING` - Repository (if not in current repo)

### Examples

```bash
# Simple issue
gh issue create --title "Fix login bug" --body "Users cannot log in"

# Issue from file
gh issue create --title "Feature request" --body-file description.md

# With labels and assignee
gh issue create --title "Bug" --body "Description" --label bug --label priority --assignee username

# In different repo
gh issue create --title "Issue" --body "Text" --repo owner/repo
```

## Comment on Issue

**Requires user permission**

```bash
gh issue comment <issue-number> [OPTIONS]
```

### Options

- `--body STRING` - Comment body (required if not using --body-file)
- `--body-file PATH` - Read body from file
- `--repo STRING` - Repository (if not in current repo)

### Examples

```bash
# Simple comment
gh issue comment 123 --body "Fixed in PR #456"

# Comment from file
gh issue comment 123 --body-file update.md

# Multi-line comment (use heredoc or file)
gh issue comment 123 --body "$(cat <<'EOF'
Update:
- Fixed the bug
- Added tests
- Updated docs
EOF
)"
```

## Edit Issue

**Requires user permission**

```bash
gh issue edit <issue-number> [OPTIONS]
```

### Options

- `--add-label STRING` - Add label
- `--remove-label STRING` - Remove label
- `--add-assignee STRING` - Add assignee
- `--remove-assignee STRING` - Remove assignee
- `--title STRING` - Update title
- `--body STRING` - Update body
- `--add-project STRING` - Add to project
- `--remove-project STRING` - Remove from project
- `--milestone STRING` - Set milestone

### Examples

```bash
# Add labels
gh issue edit 123 --add-label bug --add-label priority

# Remove label
gh issue edit 123 --remove-label wontfix

# Update title
gh issue edit 123 --title "New title for issue"

# Reassign
gh issue edit 123 --remove-assignee old-user --add-assignee new-user

# Multiple changes
gh issue edit 123 --title "Updated title" --add-label bug --add-assignee username
```

## Close Issue

**Requires user permission**

```bash
gh issue close <issue-number> [OPTIONS]
```

### Options

- `--reason STRING` - Reason for closing: completed, not planned
- `--comment STRING` - Add closing comment

### Examples

```bash
# Simple close
gh issue close 123

# Close with reason
gh issue close 123 --reason completed

# Close with comment
gh issue close 123 --comment "Fixed in v1.2.0"
```

## Reopen Issue

**Requires user permission**

```bash
gh issue reopen <issue-number>
```

### Examples

```bash
# Reopen closed issue
gh issue reopen 123
```

## Common Patterns

### Check Issue Before Starting Work

```bash
# View issue and all comments to understand context
gh issue view 123 --comments

# Check if anyone is assigned
gh issue view 123 | grep Assignees
```

### Post Work Log Reference

```bash
# After creating work log
gh issue comment 123 --body "Work log: dev/active/fix-oauth.md"
```

### Update Issue After PR

```bash
# Link PR to issue
gh issue comment 123 --body "Fixed in PR #456"

# Or close issue when PR merges
gh issue close 123 --reason completed --comment "Fixed in PR #456, merged to main"
```

### Track Progress

```bash
# Add labels as work progresses
gh issue edit 123 --add-label in-progress

# Update when ready for review
gh issue edit 123 --remove-label in-progress --add-label ready-for-review

# Close when done
gh issue close 123 --reason completed
```

## Integration with Work Logs

When working on issues:

1. View issue to understand requirements
2. Create work log in `dev/active/`
3. Reference issue in work log frontmatter
4. Post work log path to issue comments
5. Update issue when PR is created
6. Close issue when work is complete

Example workflow:

```bash
# 1. View issue
gh issue view 123 --comments

# 2. Create work log (Work tool)
# File: dev/active/fix-oauth-token.md
# Frontmatter includes: Github: https://github.com/user/repo/issues/123

# 3. Post reference to issue
gh issue comment 123 --body "Work log: dev/active/fix-oauth-token.md"

# 4. After creating PR
gh issue comment 123 --body "PR created: #456"

# 5. After PR merges
gh issue close 123 --reason completed --comment "Fixed in PR #456"
```
