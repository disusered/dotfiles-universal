# Notion Work Database Schema

## Data Source URL

**CRITICAL:** All page creation and queries MUST use this Data Source ID:

```
collection://2a0d1aba-3b72-8031-aedc-000b7ba2c45f
```

**Example usage in parent parameter:**
```json
{
  "parent": {
    "data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"
  }
}
```

## Required Properties

Every work page MUST have these properties set before creation:

### Property: Priority

**Type:** select
**Required:** Yes
**Values:**
- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

**Validation:** Must be integer 0-4

### Property: Project

**Type:** text
**Required:** Yes
**Description:** The project or team name this work belongs to

**Validation:** Non-empty string

### Property: Type

**Type:** select
**Required:** Yes
**Values:**
- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

**Validation:** Must be one of the above values

### Property: Jira issue #

**Type:** URL
**Required:** No (but ask if not provided)
**Format:** Full URL to Jira issue

**Construction pattern:**
```
https://odasoftmx.atlassian.net/browse/{issue-number}
```

**Example:** User says "Jira 2110" → Set property to `https://odasoftmx.atlassian.net/browse/2110`

**Critical:** This is a URL property, NOT text. You must provide the full constructed URL.

### Property: Github issue #

**Type:** URL
**Required:** No (but ask if not provided)
**Format:** Full URL to GitHub issue

**Construction pattern:**
```
https://github.com/{user}/{repo}/issues/{issue-number}
```

**Example:** User says "GitHub #123" and repo is "odasoftmx/app" → Set property to `https://github.com/odasoftmx/app/issues/123`

**Critical:**
- This is a URL property, NOT text. You must provide the full constructed URL.
- If the repository is unknown, you MUST STOP and ASK the user for the full repository name (e.g., "odasoftmx/sistema-escolar")

### Property: Status

**Type:** status
**Values:**
- `Not started` - Initial state
- `In Progress` - Currently being worked on
- `Done` - Completed

**Default:** `Not started`
**Usage:** Set to `In Progress` when claiming work, `Done` when complete

### Property: Name (Title)

**Type:** title
**Required:** Yes (automatically has one title property)
**Format:** Brief description of the work

**Note:** This is the page title that appears in the database view.

## Search Patterns

When looking for specific information in this schema:

```bash
# Find all property definitions
grep "^### Property:"

# Find property types
grep "^**Type:**"

# Find required properties
grep "^**Required:** Yes"

# Find date property patterns
grep "date:.*:start"

# Find URL properties
grep "URL type:"
```

## Property Name Special Cases

**Properties named "id" or "url" (case insensitive):**
- Must be prefixed with `userDefined:`
- Example: `"userDefined:URL"`, `"userDefined:id"`

This prevents collision with Notion's internal `id` and `url` fields.

## SQLite Schema

When setting properties via MCP, use this format:

```json
{
  "properties": {
    "Name": "Brief description of work",
    "Priority": 2,
    "Project": "Project Name",
    "Type": "feature",
    "Jira issue #": "https://odasoftmx.atlassian.net/browse/2110",
    "Github issue #": "https://github.com/odasoftmx/app/issues/123",
    "Status": "In Progress"
  }
}
```

**Note:** For date and place properties (if added to database later):

**Date properties** split into:
- `date:{property}:start` - Start date (YYYY-MM-DD)
- `date:{property}:end` - End date (optional, YYYY-MM-DD)
- `date:{property}:is_datetime` - 0 or 1

**Place properties** split into:
- `place:{property}:name`
- `place:{property}:address`
- `place:{property}:latitude`
- `place:{property}:longitude`
- `place:{property}:google_place_id` (optional)

## Validation Workflow

Before creating a page:

1. Check if user provided: Priority, Project, Type
2. If missing, STOP and ASK the user for the missing values
3. If Jira issue mentioned, construct full URL
4. If GitHub issue mentioned:
   - Check if repository is known
   - If unknown, STOP and ASK for full repository name
   - Construct full URL
5. Use `scripts/validate_properties.py` to verify all properties
6. Only proceed with page creation after validation passes
