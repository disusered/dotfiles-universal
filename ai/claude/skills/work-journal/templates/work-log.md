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

**CRITICAL RULES:**

1. **Journal Structure**
   - Chronological log ONLY
   - NEVER restructure or reorganize sections
   - NEVER read entire file before appending
   - ALWAYS append to end
   - Trust the Notion MCP append API

2. **What to Log (THINKING, not DOING)**

   **DO LOG:**
   - Approaches attempted and WHY chosen
   - Failures and root cause analysis
   - Decisions made and reasoning
   - Technical insights/discoveries
   - Alternative approaches considered and WHY rejected
   - Code snippets ONLY IF explanatory (showing bug logic, design pattern)

   **DO NOT LOG:**
   - Commit message writing/editing
   - PR text revisions
   - Git operations (push, pull, checkout, branch, merge, rebase, etc.)
   - File saves, basic file edits
   - Any information available in Git/GitHub/Jira logs

   **Philosophy:** If it's in Git history, DON'T duplicate it. Log your THINKING, not your DOING.

3. **Timestamps**
   - Get real system time using: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - NEVER hallucinate or offset timestamps
   - Use this command before EACH append

4. **Entry Names**
   - Descriptive only (e.g., "Identified root cause in token validation logic")
   - NO metadata that's already in table columns (dates, types, issue #s, priorities)
   - KISS principle

**Log format:**

```markdown
### [Descriptive entry name]

**Timestamp:** [output from TZ='America/Tijuana' date '+%Y-%m-%d %H:%M']

**Context:**
[What you were investigating or attempting]

**Finding/Decision:**
[What you discovered or decided, and WHY]

**Notes:**
[Interpretation, implications, next steps]

[Links to related items using references/link-formats.md patterns]
```

**Example append operations:**

```markdown
### Identified token refresh files

**Timestamp:** 2025-01-04 10:23

**Context:**
Searching codebase for refresh_token usage to understand the OAuth flow.

**Finding/Decision:**
Found 3 key files:
- src/auth/oauth.js (main implementation)
- src/auth/token-store.js (storage)
- tests/auth/oauth.test.js (tests)

Primary logic is in oauth.js, will review token expiration handling there next.

---

### Root cause in token expiration check

**Timestamp:** 2025-01-04 10:31

**Context:**
Reviewing [src/auth/oauth.js#L156-L178](https://github.com/odasoftmx/app/blob/a1b2c3d4e5f67890abcdef1234567890abcdef12/src/auth/oauth.js#L156-L178) for expiration logic.

**Finding/Decision:**
Bug in line 167: using assignment operator `=` instead of comparison `==`:
```javascript
if (token.expires_at = Date.now()) {  // BUG: assignment not comparison
```

This always evaluates to true, causing premature refresh attempts. Explains the "invalid_grant" errors.

**Notes:**
Similar pattern as [SYS-1850](https://odasoftmx.atlassian.net/browse/SYS-1850). Will use `<=` instead of `==` for edge case safety.

---

### Decided on defensive comparison approach

**Timestamp:** 2025-01-04 10:45

**Context:**
Fixing the assignment bug in token expiration check.

**Finding/Decision:**
Using `<=` instead of `==` to handle exact timestamp edge case more defensively. This prevents potential race conditions where token expires at the exact moment of the check.

**Notes:**
Alternative considered: strict equality `==`. Rejected because it's less defensive against edge cases.

---

### Test results confirm fix

**Timestamp:** 2025-01-04 11:02

**Context:**
Running existing OAuth test suite to verify fix doesn't break anything.

**Finding/Decision:**
All 15 tests passing. Fix resolves the issue without breaking existing functionality.

**Notes:**
Created follow-up task [#456](https://github.com/odasoftmx/app/issues/456) to add regression test specifically for this assignment operator bug.
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
- `{timestamp}` - Get via `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'` before each append
- `{entry-name}` - Descriptive only, no metadata (e.g., "Root cause in token expiration check")
- `{context}` - What you were investigating or attempting
- `{finding}` - What you discovered or decided, and WHY
- `{notes}` - Your interpretation, implications, next steps
- `{links}` - Formatted links per references/link-formats.md
