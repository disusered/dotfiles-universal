# Work Log Template

## Purpose

This template guides the **canonical workflow** for logging development work to Notion as it happens. This is the foundation that all other templates build upon.

## Core Philosophy

**Log as you go, not at the end.**

Work tracking is not a summary activity—it's a continuous documentation process. Append to the Notion page after EVERY significant action:
- Commands executed
- Errors encountered
- Findings discovered
- Decisions made
- Context gathered

## Workflow

### Phase 1: Pre-Work (MANDATORY)

**Before executing ANY command or starting investigation:**

1. **Create the Notion page FIRST**
   - Use `mcp__notion__create_page`
   - Parent MUST be: `{"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"}`
   - Set required properties: Priority, Project, Type, Name

2. **Validate properties before creation**
   ```bash
   python scripts/validate_properties.py --help
   python scripts/validate_properties.py --priority X --project "Y" --type Z [--jira ISSUE] [--github NUM --repo user/repo]
   ```

3. **Handle missing information**
   - If Priority, Project, or Type are not provided by the user: **STOP and ASK**
   - If Jira issue mentioned but number unclear: **STOP and ASK**
   - If GitHub issue mentioned but repo unknown: **STOP and ASK** for full repository name
   - Never guess or use defaults for required properties

4. **Construct URLs for issue properties**
   - Jira URL: `https://odasoftmx.atlassian.net/browse/{issue-id}`
   - GitHub URL: `https://github.com/{user}/{repo}/issues/{number}`
   - See `references/link-formats.md` for details

5. **Set initial status**
   - Status: `In Progress` (claiming the work)

**Example page creation:**
```json
{
  "parent": {"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"},
  "pages": [{
    "properties": {
      "Name": "Fix OAuth token refresh bug",
      "Priority": 0,
      "Project": "Authentication",
      "Type": "bug",
      "Jira issue #": "https://odasoftmx.atlassian.net/browse/SYS-2110",
      "Github issue #": "https://github.com/odasoftmx/app/issues/123",
      "Status": "In Progress"
    },
    "content": "## Work Log\n\nStarting investigation into OAuth token refresh issue.\n"
  }]
}
```

### Phase 2: Active Work (CONTINUOUS LOGGING)

**After EVERY significant action, append to the Notion page immediately.**

Use `mcp__notion__append_to_page_content` with `command: "insert_content_after"`.

**What counts as "significant action"?**
- Running a command (grep, git, test, build)
- Encountering an error
- Discovering a finding (root cause, pattern, related issue)
- Making a decision (approach chosen, option rejected)
- Gathering context (reading code, checking docs, reviewing history)

**Log format:**

**CRITICAL:** Every entry MUST start with a timestamp in format `### YYYY-MM-DD HH:MM - [Action Type]`

```markdown
### YYYY-MM-DD HH:MM - [Action Type]

**Command/Action:**
```
[exact command or action taken]
```

**Output/Result:**
[relevant output, error message, or finding]

**Notes:**
[interpretation, decisions, next steps]

[Links to related items using references/link-formats.md patterns]
```

**Example append operations:**

```markdown
### 2025-01-04 10:23 - Investigation

**Command:**
```
grep -r "refresh_token" src/auth/
```

**Output:**
Found 3 files using refresh_token:
- src/auth/oauth.js (main implementation)
- src/auth/token-store.js (storage)
- tests/auth/oauth.test.js (tests)

**Notes:**
Primary logic appears to be in oauth.js. Need to check token expiration handling.

---

### 2025-01-04 10:31 - Root Cause Found

**Action:**
Reviewed [src/auth/oauth.js#L156-L178](https://github.com/odasoftmx/app/blob/a1b2c3d4e5f67890abcdef1234567890abcdef12/src/auth/oauth.js#L156-L178)

**Finding:**
Bug in line 167: using assignment operator `=` instead of comparison `==` in token expiration check:
```javascript
if (token.expires_at = Date.now()) {  // BUG: assignment not comparison
```

This always evaluates to true, causing premature token refresh attempts.

**Notes:**
This explains the "invalid_grant" errors users are seeing. Token is being marked as expired immediately after creation.

Related to [SYS-1850](https://odasoftmx.atlassian.net/browse/SYS-1850) where similar assignment bug was found.

---

### 2025-01-04 10:45 - Fix Applied

**Command:**
```
# Edit src/auth/oauth.js line 167
# Changed: if (token.expires_at = Date.now())
# To: if (token.expires_at <= Date.now())
```

**Result:**
Fix applied and file saved.

**Notes:**
Using `<=` instead of `==` to handle exact timestamp edge case. This is more defensive.

Commit: [3f4e5d6](https://github.com/odasoftmx/app/commit/3f4e5d6789abcdef0123456789abcdef01234567)

---

### 2025-01-04 11:02 - Testing

**Command:**
```
npm test -- src/auth/oauth.test.js
```

**Output:**
All 15 tests passing ✓

**Notes:**
Existing tests now pass. Should add specific test for assignment operator bug to prevent regression.

Created follow-up task: [#456](https://github.com/odasoftmx/app/issues/456) to add regression test.
```

### Phase 3: Work Completion

**When the work is done:**

1. **Append final summary to page content**
   ```markdown
   ---

   ## Summary

   **Issue:** [Brief description of problem]
   **Root Cause:** [Technical explanation]
   **Fix:** [What was changed and why]
   **Testing:** [How it was verified]
   **Follow-up:** [Any related tasks or future work]
   ```

2. **Update page status**
   - Use `mcp__notion__update_page_properties`
   - Set Status: `Done`

3. **Respond to user with URL ONLY**
   ```
   ✅ Task complete. The work has been logged to Notion: https://www.notion.so/...
   ```

**CRITICAL: Do NOT print the work summary to the user.**

❌ **WRONG:**
```
Perfect! I've logged the OAuth fix to Notion.

Summary:
- Fixed assignment operator bug in token refresh
- Root cause was line 167 using = instead of ==
- Applied fix and all tests passing
...

The work has been logged to: https://www.notion.so/...
```

✅ **CORRECT:**
```
✅ Task complete. The work has been logged to Notion: https://www.notion.so/...
```

The summary is already in Notion. Repeating it is redundant.

## Linking Guidelines

**Critical distinction:**

- **Main tickets** (primary Jira/GitHub for this work) → Page PROPERTIES
- **Discovered/related items** → Page BODY using link formats

**DO NOT** create a "Related Tickets" section that duplicates the main issue from properties.

**DO** link to:
- Discovered related issues
- Specific commits
- Code files with line numbers
- Historical context

See `references/link-formats.md` for exact formats.

## Error Handling

**If page creation fails:**
1. Check validation output from `validate_properties.py`
2. Address each error per its `suggestion` field
3. Retry creation after fixing issues

**If append fails:**
1. Verify page ID is correct
2. Check content markdown is valid
3. Ensure you're not trying to append before page is created
4. Retry the specific append operation

**If discovered issues arise:**
1. Create NEW Notion page for the discovered work
2. Use relation property to link it to current work
3. Log the discovery in current page with link to new page

## Validation Checklist

Before considering work "logged":

- [ ] Notion page created BEFORE any commands executed
- [ ] All required properties set (Priority, Project, Type)
- [ ] Status set to "In Progress" at start
- [ ] Appended after each significant action (not batched at end)
- [ ] Links formatted per references/link-formats.md
- [ ] Main issue in properties, not duplicated in body
- [ ] Final summary appended to page content
- [ ] Status updated to "Done"
- [ ] User response contains ONLY the Notion URL

## Common Mistakes to Avoid

❌ **Running commands before creating page**
- Always create page first, log as you go

❌ **Batching all logs at the end**
- Append immediately after each action

❌ **Guessing missing properties**
- Stop and ask user for Priority, Project, Type

❌ **Printing work summary to user**
- Only provide Notion URL, summary is in page

❌ **Creating "Related Tickets" section**
- Main tickets go in properties, only link to discovered items

❌ **Using relative URLs or partial formats**
- Always use full, absolute URLs per link-formats.md

❌ **Forgetting to update status to Done**
- Mark complete when work finishes

## Template Variables

When using this template, replace:

- `{page-id}` - The Notion page ID after creation
- `{timestamp}` - Current date/time in format YYYY-MM-DD HH:MM
- `{action-type}` - Category: Investigation, Root Cause Found, Fix Applied, Testing, etc.
- `{command}` - Exact command executed
- `{output}` - Relevant command output or result
- `{notes}` - Your interpretation and decisions
- `{links}` - Formatted links per references/link-formats.md
