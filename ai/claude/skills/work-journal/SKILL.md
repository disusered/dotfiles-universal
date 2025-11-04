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

## Supported Workflows

1. **Work Logging** - Log development work to Notion as it happens
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

5. **Log continuously**
   - After EVERY command: append to page
   - After EVERY finding: append to page
   - After EVERY error: append to page
   - Format per `templates/work-log.md`

6. **Complete work**
   - Append final summary to page content
   - Update Status to "Done"
   - Respond with URL ONLY

---

## Workflow 2: PR Description Generation

**When to use:** User wants to create a GitHub Pull Request description

**Template:** `templates/pr-description.md`

**Language:** Spanish (all output)

### Process:

1. **Gather inputs**
   - Ask for: Notion Page ID(s), Source Branch, Target Branch
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

4. **Draft PR description**
   - Use format from `templates/pr-description.md`
   - Structure:
     - Resumen (why + what)
     - Trabajo Relacionado (links)
     - Cambios Realizados (categorized changes)
     - Contexto Técnico (from Notion)
     - Plan de Pruebas
     - Notas para Revisores
   - Language: Spanish
   - Tone: Technical, detailed, code-focused

5. **Iterate with user**
   - Present draft
   - Ask: "¿Esta descripción del PR captura correctamente los cambios?"
   - Adjust based on feedback
   - Repeat until approved

6. **Create PR**
   ```bash
   # Check git status
   git status

   # Push if needed
   git push -u origin {source-branch}

   # Create PR using heredoc for body
   gh pr create --base {target} --head {source} --title "{title}" --body "$(cat <<'EOF'
   [approved PR description here]
   EOF
   )"
   ```

7. **Confirm**
   - Respond: `✅ PR creado exitosamente: [URL]`

---

## Workflow 3: Manager Summary Generation

**When to use:** User wants to generate a Spanish summary for a technical manager

**Template:** `templates/manager-summary.md`

**Language:** Spanish (formal business)

### Process:

1. **PRIMARY DIRECTIVE: Find Notion Page ID**
   - Look in user's most recent message
   - If NOT clearly provided: **STOP and ASK** (in Spanish)
   - Example: "¡Claro! ¿Me pasas el ID de la página de Notion que quieres que reporte?"

2. **Fetch page data**
   - Use `mcp__notion__notion-fetch` with page ID
   - Extract properties:
     - **Jira issue #**: If empty, STOP and ASK (in Spanish)
     - **Github issue #**: If available, fetch for context

3. **Fetch GitHub context (if available)**
   - Use `mcp__github__issue_read` for original problem definition
   - Extract: bug description, expected behavior, user impact

4. **Analyze Notion log**
   - Read full page content
   - Extract:
     - Context (what system/component)
     - Technical root cause (conceptual, not line-by-line)
     - Solution applied (logical changes)
     - Metrics/data
     - Next steps

5. **Synthesize and log to Notion**
   - Generate summary in Spanish using format from `templates/manager-summary.md`:
     ```markdown
     ---

     ## Resumen de Jira (para {JIRA-ID})

     **Resumen Ejecutivo**
     [1-2 sentences on progress]

     **Logros Clave**
     - [Achievement 1 with metric]
     - [Achievement 2 with metric]

     **Contexto Técnico**
     [Conceptual explanation - NO code, NO line numbers]

     **Siguiente Pasos**
     - [Next work]

     **Bloqueadores**
     - [Blockers with impact]
     ```

   - **CRITICAL RULES:**
     - RULE 1: DO NOT FABRICATE - Only summarize from sources
     - RULE 2: CONCEPTUAL SUMMARY, NOT DIFF - Explain logic, not line changes
     - RULE 3: NO GITHUB DUPLICATION - No code snippets, line numbers, SHAs
     - RULE 4: PROFESSIONAL FORMATTING - No decorative emojis in headings
     - RULE 5: NO INVENTED DATES

   - Immediately append to original Notion page
   - DO NOT ask for approval (one-shot action)

6. **Confirm (in Spanish)**
   - `¡Listo! Ya generé el resumen y lo guardé en la página de Notion: [URL]`
   - DO NOT reprint the summary text

---

## Workflow 4: Stakeholder Update Generation

**When to use:** User wants to post a non-technical update to GitHub issue

**Template:** `templates/stakeholder-update.md`

**Language:** Spanish

### Process:

1. **Gather inputs**
   - Ask for: Notion Page ID, GitHub Issue Number
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

3. **Draft response**
   - Use format from `templates/stakeholder-update.md`:
     ```markdown
     Hola [Stakeholder],

     Este issue ya está resuelto. [Simple explanation from user perspective].

     [What changed for the user].

     **Para probar:**
     - [Specific step 1]
     - [Specific step 2]
     - [Expected result]

     Por favor háznoslo saber si está funcionando como esperas.

     ¡Gracias!
     ```

   - **Tone:** Friendly, non-technical, business value focused
   - **Language:** Spanish
   - **Avoid:** Technical jargon (OAuth, API, token, endpoint, etc.)

4. **Iterate with user**
   - Present draft
   - Ask: "¿Este mensaje comunica claramente el cambio al stakeholder?"
   - Adjust based on feedback
   - Repeat until approved

5. **Post to GitHub**
   - Use `mcp__github__issue_comment` to post approved text
   - Parameters:
     ```json
     {
       "owner": "...",
       "repo": "...",
       "issue_number": 123,
       "body": "[approved message]"
     }
     ```

6. **Confirm**
   - `✅ El comentario se ha publicado en el issue de GitHub: [URL]`

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
