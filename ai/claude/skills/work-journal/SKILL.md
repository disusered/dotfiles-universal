---
name: work-journal
description: Track technical work in Notion and generate audience-specific summaries. Use when logging work, creating PR descriptions, or generating status updates for managers and stakeholders.
allowed-tools: mcp__notion__query_database, mcp__notion__create_page, mcp__notion__update_page_properties, mcp__notion__append_to_page_content, mcp__notion__notion-create-pages, mcp__notion__notion-update-page, mcp__notion__notion-fetch, mcp__github__issue_read, mcp__github__issue_comment, mcp__github__pull_request_create, Read, Grep, Bash, mcp__git__git_status, mcp__git__git_diff, mcp__git__git_log, mcp__git__git_show
model: Sonnet
---

# Work Journaling & Communication Generation

## Purpose

This skill manages work tracking in Notion and generates audience-appropriate communications from logged work.

**Core Philosophy:** Log as you go, not at the end. Work tracking is continuous documentation.

## Language Rule

**ALL agent ↔ user communication: ENGLISH**
**ONLY final artifact outputs: SPANISH**

| Workflow | You ask questions | You confirm | Artifact output |
|----------|------------------|-------------|-----------------|
| Work Log | English | English | English (journal) |
| PR | English | English | **Spanish** (PR text) |
| Manager | English | English | **Spanish** (summary) |
| Stakeholder | English | English | **Spanish** (update) |

## Supported Workflows

1. **Work Logging** - Log development work to Notion as it happens (English)
2. **PR Descriptions** - Generate technical PR descriptions in Spanish for code review
3. **Manager Summaries** - Generate strategic summaries in Spanish for managers
4. **Stakeholder Updates** - Generate non-technical updates in Spanish for stakeholders

## How This Skill Works

**Model-Invoked Activation:**
This skill activates automatically when you detect that the user's request matches one of the supported workflows above.

**Identify the workflow by keywords:**
- "log this work", "track work", "create notion page" → Work Logging
- "PR description", "pull request", "create PR" → PR Description
- "manager summary", "resumen para manager", "jefe" → Manager Summary
- "stakeholder update", "post to github", "actualización" → Stakeholder Update

**Then dispatch to the appropriate template.**

---

## Critical Rules (Apply to ALL Workflows)

### Emoji Usage Policy

**CRITICAL: Minimize emoji usage across all outputs.**

- ❌ **NEVER** use emojis in headings or section titles
- ❌ **NEVER** use decorative emojis (✨, 🎉, 🔥, etc.)
- ✅ **ONLY** use functional emojis in bullet lists (✅, ❌, ⚠️) and **sparingly**
- ✅ If in doubt, don't use emojis

**Example:**

❌ BAD: `## 🎯 Logros Clave` → Use: `## Logros Clave`
❌ BAD: `- ✅ Feature completada exitosamente 🎉` → Use: `- Feature completada exitosamente`
✅ ACCEPTABLE (sparingly): `- ✅ Tests passing` or `- ❌ Build failed`

### Notion Integration Rules

1. **Data Source URL**
   - ALL page creation MUST use: `{"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"}`
   - See `references/notion-schema.md` for complete schema

2. **Property Validation**
   - Required properties: Priority, Project, Type
   - If ANY are missing from user request: **STOP and ASK**
   - Use `scripts/validate_properties.py` to verify before creation
   - For Jira/GitHub URLs, construct full URLs per `references/link-formats.md`

3. **Create BEFORE Execute**
   - For work logging: Create Notion page BEFORE running any commands
   - Never execute commands, then try to log them retroactively

4. **Log As You Go**
   - Use `mcp__notion__append_to_page_content` after EVERY significant action
   - Don't batch logs at the end
   - Append immediately after: commands, errors, findings, decisions

5. **URL-Only Response**
   - Final response: `✅ Task complete. The work has been logged to Notion: [URL]`
   - DO NOT print summary of logged work (it's redundant, already in Notion)

### Link Formatting Rules

- **Main tickets** (primary Jira/GitHub) → Page PROPERTIES
- **Discovered items** (related tickets, commits, code) → Page BODY
- Use exact formats from `references/link-formats.md`
- Never create "Related Tickets" section (main tickets in properties)

---

## Workflow 1: Work Logging

**When to use:** User wants to track/log work to Notion

**Template:** `templates/work-log.md`

### Process:

1. **Pre-Work Validation**
   ```bash
   # Always run validation first (with --help to see usage)
   python scripts/validate_properties.py --help
   python scripts/validate_properties.py --priority X --project "Y" --type Z
   ```

2. **Check for missing properties**
   - If Priority, Project, or Type not provided: **STOP and ASK**
   - If Jira mentioned but unclear: **STOP and ASK**
   - If GitHub mentioned but repo unknown: **STOP and ASK for full repo name**

3. **Construct URLs for properties**
   - Jira: `https://odasoftmx.atlassian.net/browse/{issue-id}`
   - GitHub: `https://github.com/{user}/{repo}/issues/{number}`
   - See `references/link-formats.md` for details

4. **Create Notion page**
   ```json
   {
     "parent": {"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"},
     "pages": [{
       "properties": {
         "Name": "...",
         "Priority": 0-4,
         "Project": "...",
         "Type": "bug|feature|task|epic|chore",
         "Jira issue #": "https://...",
         "Github issue #": "https://...",
         "Status": "In Progress"
       },
       "content": "## Work Log\n\nStarting work...\n"
     }]
   }
   ```

5. **Log continuously - FILTER BUSYWORK**

   **CRITICAL:** Journal = THINKING, not DOING. If it's in Git history, DON'T duplicate.

   **DO NOT LOG:**
   - Commit message writing/editing
   - PR text revisions
   - Git operations (push, pull, checkout, branch, merge, rebase, etc.)
   - File saves, basic file edits
   - Any information available in Git/GitHub/Jira logs

   **DO LOG:**
   - Approaches attempted and WHY chosen
   - Failures and root cause analysis
   - Decisions made and reasoning
   - Technical insights/discoveries
   - Alternative approaches considered and WHY rejected
   - Code snippets ONLY IF explanatory (showing bug logic, design pattern, NOT just "what I changed")

   **Timestamp:**
   - Get real system time: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - NEVER hallucinate or offset timestamps

   **Entry Names:**
   - Descriptive only (e.g., "Identified root cause in token validation logic")
   - NO metadata that's in table columns (dates, types, issue #s, priorities)
   - KISS principle

   **Journal Structure:**
   - Chronological log ONLY
   - NEVER restructure or reorganize sections
   - NEVER read entire file before appending
   - ALWAYS append to end using `mcp__notion__append_to_page_content`
   - Trust Notion MCP append API

6. **Complete work**
   - Append final summary to page content
   - Update Status to "Done"
   - Respond with URL ONLY

---

## Workflow 2: PR Description Generation

**When to use:** User wants to create a GitHub Pull Request description

**Template:** `templates/pr-description.md`

**Language:** All communication in English, artifact output in Spanish

**CRITICAL:** ALL PR description text MUST be in Mexican Spanish.

### Process:

1. **Gather inputs (English)**
   - Ask: "What's the Notion page ID, source branch, and target branch?"
   - If missing: STOP and ASK

2. **Analyze context (the "why")**
   - Use `mcp__notion__notion-fetch` to read Notion page(s)
   - Extract: Technical Summary, Goal, Root Cause

3. **Analyze changes (the "what")**
   - Use git tools to inspect changes:
     ```bash
     git diff origin/{target}...{source}
     git log origin/{target}..{source} --oneline
     ```
   - Summarize: files changed, components affected, patterns used

4. **Draft PR description in Spanish**
   - Use format from `templates/pr-description.md`
   - **VERIFY output language is Spanish before proceeding**
   - Structure:
     - Resumen (why + what)
     - Trabajo Relacionado (links)
     - Cambios Realizados (categorized changes)
     - Contexto Técnico (from Notion)
     - Plan de Pruebas
     - Notas para Revisores
   - Tone: Technical, detailed, code-focused

5. **Iterate with user (English)**
   - Present draft (in Spanish)
   - Ask (in English): "Does this PR description capture the changes correctly?"
   - Adjust based on feedback
   - Repeat until approved

6. **Create child page with PR text**
   - Get timestamp: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - Create child page of journal with title: `PR Description - {timestamp}`
   - Page content: Approved Spanish PR text
   - Use Notion's `<page>PR Description - {timestamp}</page>` syntax in append

7. **Confirm (English)**
   - `✅ PR description created: [child page URL]`
   - User can copy text from child page to GitHub PR

---

## Workflow 3: Manager Summary Generation

**When to use:** User wants to generate a Spanish summary for a technical manager

**Template:** `templates/manager-summary.md`

**Language:** All communication in English, artifact output in Spanish

### Process:

1. **Gather inputs (English)**
   - Ask: "What's the Notion page ID for the work log?"
   - If missing: STOP and ASK
   - If Jira issue # property is empty: STOP and ASK

2. **Analyze context**
   - Use `mcp__notion__notion-fetch` to read page
   - If GitHub issue # available, use `mcp__github__issue_read` for context
   - Extract:
     - Context (what system/component)
     - Technical root cause (conceptual, not line-by-line)
     - Solution applied (logical changes)
     - Metrics/data
     - Next steps/blockers

3. **Draft manager summary in Spanish**
   - Use format from `templates/manager-summary.md`
   - **VERIFY output language is Spanish before proceeding**
   - **CRITICAL RULES:**
     - DO NOT FABRICATE - Only summarize from sources
     - CONCEPTUAL SUMMARY, NOT DIFF - Explain logic, not line changes
     - NO GITHUB DUPLICATION - No code snippets, line numbers, SHAs
     - PROFESSIONAL FORMATTING - No decorative emojis in headings
     - NO INVENTED DATES
   - Tone: Strategic, high-level, business-impact focused

4. **Create child page with summary**
   - Get timestamp: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - Create child page of journal with title: `Manager Summary - {timestamp}`
   - Page content: Spanish manager summary
   - Use Notion's `<page>Manager Summary - {timestamp}</page>` syntax in append
   - DO NOT ask for approval (one-shot action)

5. **Confirm (English)**
   - `✅ Manager summary created: [child page URL]`
   - DO NOT reprint the summary text

---

## Workflow 4: Stakeholder Update Generation

**When to use:** User wants to create a non-technical update for stakeholders

**Template:** `templates/stakeholder-update.md`

**Language:** All communication in English, artifact output in Spanish

### Process:

1. **Gather inputs (English)**
   - Ask: "What's the Notion page ID for the work log?"
   - If missing: STOP and ASK

2. **Analyze work log**
   - Use `mcp__notion__notion-fetch` to read page
   - Focus on:
     - Business Impact / Goal sections
     - User-facing changes
   - Ignore:
     - Implementation details
     - Code specifics
     - Architecture

3. **Draft stakeholder update in Spanish**
   - Use format from `templates/stakeholder-update.md`
   - **VERIFY output language is Spanish before proceeding**
   - **Tone:** Professional, non-technical, business value focused
   - **Avoid:** Technical jargon (OAuth, API, token, endpoint, etc.)
   - **DO NOT FABRICATE:** Only summarize what's in the work log

4. **Iterate with user (English)**
   - Present draft (in Spanish)
   - Ask (in English): "Does this stakeholder update communicate the changes clearly?"
   - Adjust based on feedback
   - Repeat until approved

5. **Create child page with update**
   - Get timestamp: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - Create child page of journal with title: `Stakeholder Update - {timestamp}`
   - Page content: Approved Spanish stakeholder update
   - Use Notion's `<page>Stakeholder Update - {timestamp}</page>` syntax in append

6. **Confirm (English)**
   - `✅ Stakeholder update created: [child page URL]`
   - User can copy text from child page to GitHub or other communication channels

---

## References

When you need detailed information:

- **Notion schema:** Read `references/notion-schema.md` for property definitions, SQLite schema, and data source URL
- **Link formats:** Read `references/link-formats.md` for Jira/GitHub/code/commit URL construction patterns
- **Work logging:** Read `templates/work-log.md` for canonical logging workflow
- **PR description:** Read `templates/pr-description.md` for PR format and tone guidelines
- **Manager summary:** Read `templates/manager-summary.md` for Spanish manager format and critical rules
- **Stakeholder update:** Read `templates/stakeholder-update.md` for non-technical Spanish format

## Validation Script Usage

Before creating Notion pages, use the validation script:

```bash
# First, check help
python scripts/validate_properties.py --help

# Then validate
python scripts/validate_properties.py --priority 1 --project "Auth" --type bug --jira 2110 --github 123 --repo "odasoftmx/app"
```

The script returns JSON with:
- `valid`: boolean
- `errors`: array of validation errors with agent-centric suggestions
- `urls`: constructed Jira and GitHub URLs

**If validation fails:**
- Read the `suggestion` field for each error
- Address the issue (usually: ask user for missing info)
- Re-run validation

---

## Common Patterns

### Multi-Output Request

**User:** "I finished the OAuth fix. Create PR description and manager summary."

**Your response:**
1. Identify both outputs requested: PR + manager summary
2. Fetch Notion page data once (shared context)
3. Load `templates/pr-description.md`
4. Generate PR description
5. Iterate with user until approved
6. Create PR
7. Load `templates/manager-summary.md`
8. Generate manager summary
9. Append to Notion immediately (no approval needed for this)
10. Confirm both completed

### Discovered Related Work

**While logging work, you discover a related issue:**

1. Continue logging current work
2. In the log, mention the discovery:
   ```markdown
   ### Discovery

   Found related issue: [SYS-1850](https://odasoftmx.atlassian.net/browse/SYS-1850)
   which had similar assignment operator bug.
   ```
3. If the discovered issue needs work:
   - Create NEW Notion page for it
   - Link via relation property
   - Log the link in current page body

---

## Error Handling

### Validation Fails
- Read error suggestions from `validate_properties.py` output
- Ask user for missing/incorrect information
- Re-validate before proceeding

### Page Creation Fails
- Check validation output
- Verify data source ID is correct
- Ensure properties match schema
- Retry after fixing

### Append Fails
- Verify page ID is correct
- Check markdown is valid Notion-flavored markdown
- Ensure page was created before trying to append
- Retry the append operation

### User Blocks During Iteration
- If user rejects draft, ask what to change
- Make adjustments
- Re-present for approval
- Don't proceed until approved

---

## Success Criteria

You've completed your job when:

- ✅ For work logging: Notion page created, work logged continuously, status updated to Done, URL provided
- ✅ For PR: Draft approved by user, PR created in GitHub, URL provided
- ✅ For manager summary: Summary generated and appended to Notion, URL provided (in Spanish)
- ✅ For stakeholder update: Draft approved by user, comment posted to GitHub, URL provided

---

## Important Notes

- **Language Awareness:** Work logging uses English (technical logs). All audience outputs (PR, manager, stakeholder) use Spanish.
- **Approval Gates:** PR and stakeholder updates require user approval. Manager summaries are one-shot (no approval).
- **Notion First:** Always create Notion page before running commands (for work logging).
- **URL Construction:** Always use full, absolute URLs per `references/link-formats.md`.
- **No Redundant Summaries:** Never print logged work back to user; just provide URL.
- **Property Validation:** Always validate before page creation to prevent errors.
