---
name: jiratui
description: Use jiratui CLI to interact with Jira (view issues, add comments, query). Load this when you need to perform Jira operations.
allowed-tools: Bash
---

# jiratui CLI Reference

Command-line interface for Jira issues and comments.

## Basic Syntax

```bash
jiratui [COMMAND] [SUBCOMMAND] [OPTIONS] [ARGS]
```

## Commands

### Issues

#### List issues

```bash
jiratui issues list [OPTIONS]

# Options:
#   --jql TEXT          JQL query to filter issues
#   --max-results INT   Maximum number of results (default: 50)
#   --fields TEXT       Comma-separated list of fields to include

# Examples:
jiratui issues list --jql "project = CM AND status = 'In Progress'"
jiratui issues list --max-results 10
```

#### View issue details

```bash
jiratui issues view <issue-key>

# Example:
jiratui issues view CM-2766
```

#### Create issue

```bash
jiratui issues create [OPTIONS]

# Options:
#   --project TEXT      Project key (required)
#   --summary TEXT      Issue summary (required)
#   --description TEXT  Issue description
#   --issue-type TEXT   Issue type (default: Task)

# Example:
jiratui issues create --project CM --summary "Fix OAuth bug" --issue-type Bug
```

### Comments

**CRITICAL: The `comments` command ALWAYS requires a subcommand (add/list/delete).**

#### Add comment

```bash
jiratui comments add <issue-key> [OPTIONS]

# Options:
#   --body TEXT         Comment body (required if not using --file)
#   --file PATH         Read comment from file
#   --markdown          Treat input as markdown (use with --file)

# Examples:
jiratui comments add CM-2766 --body "Updated the implementation"
jiratui comments add CM-2766 --file summary.md --markdown
echo "Comment text" | jiratui comments add CM-2766 --body -
```

#### List comments

```bash
jiratui comments list <issue-key>

# Example:
jiratui comments list CM-2766
```

#### Delete comment

```bash
jiratui comments delete <issue-key> <comment-id>

# Example:
jiratui comments delete CM-2766 12345
```

## Common Errors

### ❌ Missing subcommand

**WRONG:**
```bash
jiratui comments CM-2766
```

**ERROR:** `No such command 'CM-2766'`

**CORRECT:**
```bash
jiratui comments add CM-2766 --body "text"
# or
jiratui comments list CM-2766
```

**Explanation:** The `comments` command requires a subcommand (`add`, `list`, or `delete`), not just an issue key.

### ❌ Missing --body or --file

**WRONG:**
```bash
jiratui comments add CM-2766
```

**ERROR:** `Missing option '--body' or '--file'`

**CORRECT:**
```bash
jiratui comments add CM-2766 --body "Comment text"
# or
jiratui comments add CM-2766 --file /tmp/comment.md --markdown
```

## Common Patterns

### Post manager summary to Jira

```bash
# Create temporary file with summary
cat > /tmp/summary.md << 'EOF'
## CM-2766

**Resumen Ejecutivo**
Se corrigió bug crítico...
EOF

# Post to Jira issue
jiratui comments add CM-2766 --file /tmp/summary.md --markdown
```

### Check issue before working

```bash
# View full issue details
jiratui issues view CM-2766

# List recent comments
jiratui comments list CM-2766
```

### Query for related issues

```bash
# Find all in-progress issues in project
jiratui issues list --jql "project = CM AND status = 'In Progress'"

# Find issues assigned to you
jiratui issues list --jql "assignee = currentUser()"
```

## Getting Help

Use `--help` on any command or subcommand:

```bash
jiratui --help
jiratui issues --help
jiratui comments --help
jiratui comments add --help
```
