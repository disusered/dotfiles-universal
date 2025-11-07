---
name: work-journal
description: Generate audience-specific communications from Notion work logs. Use when creating PR descriptions, or generating status updates for managers and stakeholders. (Note: Basic work logging is handled by CLAUDE.md directives, not this skill.)
allowed-tools: mcp__notion__query_database, mcp__notion__update_page_properties, mcp__notion__append_to_page_content, mcp__notion__notion-update-page, mcp__notion__notion-fetch, Read, Grep, Bash, mcp__git__git_status, mcp__git__git_diff, mcp__git__git_log, mcp__git__git_show
model: sonnet
---

# Work Journal Communication Generation

## Purpose

This skill generates audience-appropriate communications from Notion work logs that were created using CLAUDE.md directives.

**IMPORTANT:** This skill does NOT handle basic work logging. That's handled automatically by CLAUDE.md directives.

## Language Rule

**CRITICAL - READ THIS CAREFULLY:**

**ALL agent ↔ user communication: ENGLISH ONLY**
**ALL work log content: ENGLISH ONLY**
**ONLY final artifact outputs: SPANISH**

| Content Type | Language |
|-------------|----------|
| Questions to user | English |
| Confirmations | English |
| Work log entries | **ENGLISH** |
| PR descriptions | Spanish |
| Manager summaries | Spanish |
| Stakeholder updates | Spanish |

**NEVER translate existing work logs to Spanish. Work logs stay in English.**

## Supported Workflows

1. **PR Descriptions** - Generate technical PR descriptions in Spanish for code review
2. **Manager Summaries** - Generate strategic summaries in Spanish for managers
3. **Stakeholder Updates** - Generate non-technical updates in Spanish for stakeholders

## How This Skill Works

**Model-Invoked Activation:**
This skill activates when you detect that the user's request matches one of the supported workflows above.

**Identify the workflow by keywords:**
- "PR description", "pull request", "create PR" → PR Description
- "manager summary", "resumen para manager", "jefe" → Manager Summary
- "stakeholder update", "post to github", "actualización" → Stakeholder Update

**Then dispatch to the appropriate template.**

**Note:** If user mentions "log work" or "track work", that's handled by CLAUDE.md, not this skill.

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

1. **Fetch Work Logs**
   - Use `mcp__notion__notion-fetch` to read existing work log pages
   - Extract page properties (Jira, GitHub, Project, etc.)
   - Read page content (work log entries)

2. **Create Child Pages**
   - All artifacts (PR descriptions, summaries, updates) go in child pages
   - Use Notion's `<page>Title</page>` syntax when appending
   - Get timestamp: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`

3. **Update Properties**
   - Use `mcp__notion__update_page_properties` to update Status, etc.
   - Don't recreate pages that already exist

4. **URL-Only Confirmations**
   - Final response: `✅ [Artifact type] created: [child page URL]`
   - DO NOT reprint the artifact content (it's in Notion)

### Link Formatting Rules

- Use exact formats from `references/link-formats.md`
- Jira: `https://odasoftmx.atlassian.net/browse/{ID}`
- GitHub: `https://github.com/{user}/{repo}/issues/{NUM}`

---

## Workflow 1: PR Description Generation

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

6. **Create child page with PR text AND create PR in GitHub**
   - Get timestamp: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - Create child page of journal with title: `PR Description - {timestamp}`
   - Page content: Approved Spanish PR text
   - Use Notion's `<page>PR Description - {timestamp}</page>` syntax in append
   - **Create PR using gh CLI:**
     ```bash
     gh pr create --base {target} --head {source} --title "{title}" --body "{approved PR text in Spanish}"
     ```
   - **CRITICAL: DO NOT update Status to "Done"** - Work is not complete until PR is merged
   - Leave Status as "In Progress" after PR creation

7. **Confirm (English)**
   - `✅ PR created: [GitHub PR URL]`
   - `✅ PR description archived to Notion: [child page URL]`
   - `⚠️ Work remains In Progress until PR is merged`

---

## Workflow 2: Manager Summary Generation

**When to use:** User wants to generate a Spanish summary for a technical manager

**Template:** `templates/manager-summary.md`

**Language:** All communication in English, artifact output in Spanish

### Process:

1. **Find the work log page (English)**
   - If user provides Jira URL: Extract issue key and query database by Jira property
   - If user provides Notion page URL/ID: Use that directly
   - Use `mcp__notion__query_database` to search by Jira property if given Jira URL
   - If page not found or Jira property is empty: STOP and ASK
   - **DO NOT create new pages - only work with existing work logs**

2. **Analyze context**
   - Use `mcp__notion__notion-fetch` to read page
   - If GitHub issue # available, use `gh issue view {number}` for context
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
     - BE CONCISE - 2-3 paragraphs max, clear and direct
     - DO NOT FABRICATE - Only summarize from sources
     - CONCEPTUAL SUMMARY, NOT DIFF - Explain logic, not line changes
     - NO GITHUB DUPLICATION - No code snippets, line numbers, SHAs
     - NO DECORATIVE FORMATTING - No emojis, no excessive bullets
     - NO INVENTED DATES
     - WRITE LIKE A HUMAN - Clear, direct, professional
   - Tone: Strategic, high-level, business-impact focused, CONCISE

4. **Create CHILD PAGE (not append!) AND post to Jira**
   - Get timestamp: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - **CRITICAL:** Use `mcp__notion__create_page` to create a NEW CHILD PAGE
   - Parent: The work log page ID you found in step 1
   - Child page title: `Manager Summary - {timestamp}`
   - Child page content: Spanish manager summary
   - **DO NOT use append_to_page_content on the work log - CREATE CHILD PAGE**
   - **Post comment to Jira using jiratui:**
     ```bash
     echo "{Spanish manager summary}" | jiratui comments {jira-issue-key} --add
     ```
   - Extract Jira issue key from page properties (from URL like `CM-2765`)
   - DO NOT ask for approval (one-shot action)

5. **Confirm (English)**
   - `✅ Manager summary posted to Jira: [Jira issue URL]`
   - `✅ Manager summary archived to Notion: [child page URL]`
   - DO NOT reprint the summary text

---

## Workflow 3: Stakeholder Update Generation

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

5. **Create child page with update AND post to GitHub**
   - Get timestamp: `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
   - Create child page of journal with title: `Stakeholder Update - {timestamp}`
   - Page content: Approved Spanish stakeholder update
   - Use Notion's `<page>Stakeholder Update - {timestamp}</page>` syntax in append
   - **Post comment to GitHub issue using gh CLI:**
     ```bash
     gh issue comment {issue-number} --body "{approved Spanish stakeholder update}"
     ```
   - Extract issue number from page properties (from URL like `123`)
   - Ensure you're in the correct repository or use `--repo user/repo` flag

6. **Confirm (English)**
   - `✅ Stakeholder update posted to GitHub: [GitHub issue URL]`
   - `✅ Stakeholder update archived to Notion: [child page URL]`

---

## References

When you need detailed information:

- **Link formats:** Read `references/link-formats.md` for Jira/GitHub/code/commit URL construction patterns
- **PR description:** Read `templates/pr-description.md` for PR format and tone guidelines
- **Manager summary:** Read `templates/manager-summary.md` for Spanish manager format and critical rules
- **Stakeholder update:** Read `templates/stakeholder-update.md` for non-technical Spanish format

**Note:** For basic work logging instructions, see CLAUDE.md (not this skill).

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

---

## Error Handling

### Page Fetch Fails
- Verify page ID is correct
- Ask user for the correct Notion page URL/ID
- Ensure page exists

### Child Page Creation Fails
- Verify parent page ID is correct
- Check markdown is valid Notion-flavored markdown
- Retry the operation

### User Blocks During Iteration
- If user rejects draft, ask what to change
- Make adjustments
- Re-present for approval
- Don't proceed until approved

---

## Success Criteria

You've completed your job when:

- ✅ For PR: Draft approved by user, PR created in GitHub using `gh pr create`, child page created in Notion, URLs provided
- ✅ For manager summary: Summary generated, comment posted to Jira using `jiratui`, child page created in Notion, URLs provided (in Spanish)
- ✅ For stakeholder update: Draft approved by user, comment posted to GitHub issue using `gh issue comment`, child page created in Notion, URLs provided

---

## Important Notes

- **Language Awareness:** All artifacts (PR, manager, stakeholder) use Spanish. Agent ↔ user communication uses English.
- **Approval Gates:** PR and stakeholder updates require user approval. Manager summaries are one-shot (no approval).
- **Work Logging:** Basic work logging is NOT handled by this skill - see CLAUDE.md for those directives.
- **URL Construction:** Always use full, absolute URLs per `references/link-formats.md`.
- **No Redundant Content:** Never reprint artifact content; just provide child page URL.
