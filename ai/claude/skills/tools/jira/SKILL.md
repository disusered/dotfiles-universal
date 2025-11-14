---
name: jira
description: Use acli (Atlassian CLI) to interact with Jira (view work items, add comments, query). Load this when you need to perform Jira operations.
allowed-tools: Bash
---

# acli Jira CLI Reference

Official Atlassian CLI for Jira work items and comments.

## Basic Syntax

```bash
acli jira [COMMAND] [OPTIONS]
```

## Commands

### Work Items

#### View work item details

```bash
acli jira workitem view --key "<issue-key>"

# Example:
acli jira workitem view --key "CM-2766"
```

#### List work items

```bash
acli jira workitem list [OPTIONS]

# Options:
#   --jql TEXT          JQL query to filter work items
#   --max-results INT   Maximum number of results

# Examples:
acli jira workitem list --jql "project = CM AND status = 'In Progress'"
acli jira workitem list --max-results 10
```

#### Create work item

```bash
acli jira workitem create [OPTIONS]

# Options:
#   --summary TEXT      Work item summary (required)
#   --project TEXT      Project key (required)
#   --type TEXT         Work item type (default: Task)
#   --description TEXT  Work item description

# Example:
acli jira workitem create --summary "Fix OAuth bug" --project "CM" --type "Bug"
```

#### Edit work item

```bash
acli jira workitem edit --key "<issue-key>" [OPTIONS]

# Options:
#   --summary TEXT      New summary
#   --description TEXT  New description

# Example:
acli jira workitem edit --key "CM-2766" --summary "Updated OAuth implementation"
```

#### Transition work item status

```bash
acli jira workitem transition --key "<issue-key>" --status "<status>"

# Example:
acli jira workitem transition --key "CM-2766" --status "In Progress"
```

### Comments

#### Add comment

**IMPORTANT:** `acli` requires ADF (Atlassian Document Format) for rich text formatting.

```bash
acli jira workitem comment create --key "<issue-key>" --body "<comment-text>"

# Simple text comment:
acli jira workitem comment create --key "CM-2766" --body "Updated the implementation"

# Rich text comment using ADF (from markdown):
# Step 1: Write markdown
cat > summary.md << 'EOF'
## Summary

**Bold text** and *italic*.

- Bullet 1
- Bullet 2
EOF

# Step 2: Convert markdown to ADF
~/dotfiles-universal/bin/md-to-adf summary.md > summary-adf.json

# Step 3: Post ADF to Jira
acli jira workitem comment create --key "CM-2766" --body "$(cat summary-adf.json)"
```

#### List comments

```bash
acli jira workitem comment list --key "<issue-key>"

# Example:
acli jira workitem comment list --key "CM-2766"
```

## Common Patterns

### Post manager summary to Jira

```bash
# Post Spanish manager summary to Jira issue with rich formatting
# Step 1: Manager summary is saved as markdown in dev/artifacts/
# (e.g., dev/artifacts/fix-oauth-manager-2025-11-14-1430.md)

# Step 2: Convert markdown to ADF
~/dotfiles-universal/bin/md-to-adf dev/artifacts/fix-oauth-manager-2025-11-14-1430.md > /tmp/manager-adf.json

# Step 3: Post ADF to Jira
acli jira workitem comment create --key "CM-2766" --body "$(cat /tmp/manager-adf.json)"

# One-liner version:
acli jira workitem comment create --key "CM-2766" --body "$(~/dotfiles-universal/bin/md-to-adf dev/artifacts/fix-oauth-manager-2025-11-14-1430.md)"
```

### Check work item before working

```bash
# View full work item details
acli jira workitem view --key "CM-2766"

# List recent comments
acli jira workitem comment list --key "CM-2766"
```

### Query for related work items

```bash
# Find all in-progress issues in project
acli jira workitem list --jql "project = CM AND status = 'In Progress'"

# Find issues assigned to you
acli jira workitem list --jql "assignee = currentUser()"
```

## Common Errors

### ❌ Invalid work item key

**ERROR:** `Issue does not exist or you do not have permission to see it`

**SOLUTION:** Verify the issue key format (e.g., "CM-2766") and ensure you have access to the project.

### ❌ Comment posted as raw markdown or JSON instead of formatted text

**PROBLEM:** Comments appear as raw markdown (`## Heading`, `**bold**`) or raw JSON in Jira.

**CAUSE:** Jira requires ADF (Atlassian Document Format) for rich text. Markdown is not automatically converted.

**SOLUTION:** Convert markdown to ADF before posting:

```bash
# Convert markdown to ADF, then post to Jira
~/dotfiles-universal/bin/md-to-adf summary.md | \
  xargs -0 -I {} acli jira workitem comment create --key "CM-123" --body "{}"

# Or save intermediate ADF file:
~/dotfiles-universal/bin/md-to-adf summary.md > summary-adf.json
acli jira workitem comment create --key "CM-123" --body "$(cat summary-adf.json)"
```

**Tool:** The `md-to-adf` script is located at `~/dotfiles-universal/bin/md-to-adf` and uses the `marklassian` library (requires `npm install -g marklassian`)

## Getting Help

Use `--help` on any command:

```bash
acli jira --help
acli jira workitem --help
acli jira workitem view --help
acli jira workitem comment --help
```
