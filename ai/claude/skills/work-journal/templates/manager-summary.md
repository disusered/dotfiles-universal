# Template: Manager Summary

## Purpose

This template guides the generation of conceptual technical summaries in Spanish for technical managers, reading an English work log from Notion and its linked GitHub issue.

## Audience

**Technical manager who understands engineering concepts.**

The summary should:

- Explain the **logic** of the fix, not paste the diff
- Focus on progress, metrics, and business impact
- Use high-level technical concepts (no implementation details)
- Be actionable (next steps, blockers)

## Language

**CRITICAL - READ CAREFULLY:**

**ALL agent ↔ user communication: ENGLISH**
**ALL work log content: ENGLISH (DO NOT TRANSLATE)**
**ONLY manager summary artifact: SPANISH (formal business Spanish)**

The manager summary itself must be in Spanish, but:
- All questions to user: English
- All confirmations: English
- Work logs: English (NEVER translate)
- Manager summary artifact: Spanish

## Critical Rules

### RULE 1: DO NOT FABRICATE

Your **only** task is to synthesize information from your sources (Notion log, GitHub issue).

❌ **DO NOT** invent:

- Metrics not in the sources
- Technical details not mentioned
- Dates or timelines not specified
- Next steps not documented

✅ **DO** summarize:

- Explicit information in the Notion log
- Data from the GitHub issue
- Progress visible in commits/changes

### RULE 2: CONCEPTUAL SUMMARY, NOT DIFF

Explain the **logic** of the fix, don't regurgitate line-by-line changes.

✅ **GOOD (Conceptual Technical):**
"Se corrigió un condicional que usaba asignación (`=`) en lugar de comparación (`==`), causando que los tokens se marcaran como expirados inmediatamente."

❌ **BAD (Regurgitated Diff):**
"Se cambió la línea 167 de `if (token.expires_at = Date.now())` a `if (token.expires_at == Date.now())`."

### RULE 3: NO DUPLICATION OF SYSTEM DATA

**CRITICAL: Do not duplicate information available in other systems.**

DO NOT include:

- ❌ Code snippets (visible in GitHub)
- ❌ Line numbers (visible in GitHub)
- ❌ Commit SHAs (visible in git log)
- ❌ Links to git files (visible in GitHub)
- ❌ GitHub issue numbers (already in Notion properties)
- ❌ Jira issue numbers (already in Notion properties)
- ❌ Commit messages (visible in git log)
- ❌ PR descriptions (visible in GitHub)
- ❌ File change lists (visible in git diff)

**Your job is to SYNTHESIZE the "why" and "impact", not COPY the "what" from other tools.**

Notion properties, GitHub UI, Jira, and git logs already contain this data. Don't repeat it.

### RULE 4: PROFESSIONAL FORMATTING

- ❌ DO NOT use decorative emojis in headings or anywhere
- ❌ DO NOT use casual headings (e.g., "Done", "All good!")
- ✅ DO maintain professional report tone
- ✅ DO use plain text throughout

### RULE 5: NO INVENTED DATES

DO NOT include completion dates (e.g., "Completed on January 4").

Dates are already in Notion properties and GitHub. Don't invent or assume undocumented dates.

## Workflow

### Step 1: PRIMARY DIRECTIVE - Find Notion Page (English)

**Your first job is to find the Notion Page.**

**If user provides Jira URL:**
1. Extract the Jira issue key (e.g., CM-2765 from https://odasoftmx.atlassian.net/browse/CM-2765)
2. Use `mcp__notion__query_database` to search for page where Jira property matches that URL
3. If found, use that page ID
4. If not found, STOP and tell user no page exists for that Jira issue

**If user provides Notion page URL/ID:**
1. Extract page ID from URL or use ID directly
2. Use that page ID

**If NOT clearly provided:**
- **STOP** immediately
- **ASK** (in English): "What's the Notion page or Jira URL for the work log?"

**Do not proceed to any other step until you have the page ID.**

### Step 2: Get Page Data (CRITICAL)

**Once you have the Page ID:**

1. **Get the page object** to read its **properties**
   - Use `mcp__notion__notion-fetch` with the page ID

2. **Extract required properties:**
   - **Jira ID:** Extract the `Jira` property URL
     - If **empty**, **STOP** and ask the user (in English) for the Jira ID
     - Example: "I need the Jira ID for this work (e.g., PROJ-123). Can you provide it?"
   - **GitHub ID:** Extract the `Github` property URL (if available)

### Step 3: Get GitHub Context (if available)

**If a `Github` property URL was found:**

1. Use `gh issue view` to read the GitHub issue
2. Extract the **original problem definition**:
   - Reported bug description
   - Expected vs actual behavior
   - User impact
   - Business context

**If NO GitHub issue:** Proceed with Notion log only.

### Step 4: Analyze Notion Log (Internal)

**Read the full page content (blocks).**

This is your primary source for the **resolution**.

**Extract:**

1. **Context:**
   - What system/component?
   - What user flow?
   - What type of problem? (bug, feature, improvement)

2. **Technical root cause:**
   - What caused the problem? (logic bug, race condition, undefined variable, dead code)
   - Conceptual explanation (without mentioning specific lines)

3. **Solution applied:**
   - What was changed logically?
   - Why this approach?
   - What does it improve/fix?

4. **Metrics/Data:**
   - Tests passing (how many)
   - Performance improvements (if mentioned)
   - Users impacted (if mentioned)

5. **Next steps:**
   - Pending work mentioned
   - Follow-up tasks created
   - Blockers identified

### Step 5: Synthesize and Create Child Page (CRITICAL)

**CRITICAL: The manager summary output must be in Spanish.**

**Synthesize your findings into a conceptual technical summary in formal Mexican Spanish.**

**CONCISENESS RULE:**
- 2-3 sentences per section MAX
- No bullet lists longer than 3 items
- Clear, direct language - no fluff
- If you can say it in 10 words, don't use 20

**CONSISTENCY RULE:**
- The summary you create in the child page MUST match what you show the user
- DO NOT change wording, structure, or content between preview and final output
- Generate it once and use that exact version

**Formato requerido:**

```markdown
---

## {JIRA-ID}

**Resumen Ejecutivo**
[1-2 frases sobre el progreso general. Enfocarse en qué se logró y el impacto.]

**Logros Clave**

- [Logro 1 con métrica, si está disponible]
- [Logro 2 con métrica, si está disponible]
- [Logro 3 con impacto al negocio o técnico]

**Contexto Técnico**
[Explicación conceptual de la causa raíz y la solución. Sin código, sin líneas, solo lógica.]

**Siguiente Pasos**

- [Próximo trabajo de prioridad alta, si está documentado]
- [Próximo trabajo de prioridad media, si está documentado]

**Bloqueadores**
[Solo si hay bloqueadores documentados. Incluir impacto y acción requerida.]

- [Bloqueador con impacto + acción necesaria]
```

**CRITICAL INSTRUCTIONS FOR CREATING CHILD PAGE:**

1. **THE WORK LOG PAGE IS READ-ONLY**
   - You MUST NOT modify the work log page content
   - You MUST NOT append to the work log page
   - You MUST NOT translate the work log page
   - The work log page is your INPUT - you only READ from it

2. **Get timestamp**
   ```bash
   TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'
   ```

3. **Create a NEW CHILD PAGE nested under the work log**
   - Use `mcp__notion__create_page` with:
     - `parent: { page_id: "{the work log page ID from step 1}" }`
     - `title: "Manager Summary - {timestamp}"`
     - `content: "{the EXACT Spanish summary you generated and showed to user}"`
   - This creates a SEPARATE page nested under the work log
   - DO NOT use `append_to_page_content` - that would modify the work log

4. **Upload the EXACT content you showed the user**
   - Generate the summary ONCE
   - Show it to the user (they'll see it in output)
   - Upload that EXACT text to the child page
   - DO NOT regenerate, rewrite, or "improve" it

5. **DO NOT ask for approval** - This is a one-shot action: generate and create immediately
6. **Use the Jira ID** you found in Step 2 for the summary heading

### Step 6: Add Artifact Link to Work Log

**After creating the child page, append a link to the work log:**

1. **Check if "## Artifacts" section exists** in the work log
   - If not, create it by appending `\n## Artifacts\n\n`

2. **Append the artifact link** using `mcp__notion__append_to_page_content`:
   ```markdown
   - [Manager Summary - {timestamp}]({child-page-url})
   ```

**This creates a clear reference in the work log to all generated artifacts.**

### Step 7: Final Step (English)

**Confirm to the user (in English) that the summary has been generated and saved to Notion.**

**Provide ONLY the URL to the child page.**

**DO NOT reprint the summary text.**

**Example:**

```
✅ Manager summary created: https://www.notion.so/...
```

## Tone Guidelines

**For agent ↔ user communication (English):**

- Clear, direct questions
- Professional but conversational
- Seek clarification when needed

**For manager summary artifact (Spanish):**

- **Audience:** Technical manager (Spanish speaker)
- **Language:** Spanish (formal business, Mexican)
- **Technical level:** Medium (understands concepts, wants results)
- **Length:** 2-3 sentences per section maximum
- **Style:** Data-driven, strategic focus, actionable

## Content Priorities

### Include (Primary)

- Business impact
- Metrics and data
- Progress and timeline (only if documented)
- Concrete next steps
- Blockers with required actions

### Include (Secondary)

- Technical approach (high level only)
- Root cause (conceptual, no code)
- Important technical decisions

### Exclude

- Implementation details
- Code specifications
- Line numbers, commit SHAs
- Granular tasks (unless they are blockers)
- Duplicate information from GitHub/Jira

## Information Sources

From Notion work log, extract:

- **Completed tasks** → Key Achievements
- **Planned work** → Next Steps
- **Problems/Blockers** → Blockers
- **Metrics/data** → Include in all sections

From GitHub issue (if available):

- **Problem description** → Context
- **User impact** → Executive Summary
- **Expected behavior** → To contrast with solution

## Example Output

```markdown
---

## SYS-2110

**Resumen Ejecutivo**
Se corrigió bug crítico en OAuth que causaba errores `invalid_grant`. El operador de asignación en lugar de comparación marcaba tokens como expirados inmediatamente.

**Logros Clave**
- Corregido operador lógico en validación de tokens
- 15 tests unitarios pasando
- Reducción de 40% en llamadas innecesarias a API de OAuth

**Contexto Técnico**
El código usaba `=` (asignación) en lugar de `==` (comparación) en la verificación de expiración. La solución corrigió el operador y es backward-compatible.

**Siguiente Pasos**
- Deploy a producción esta semana
- Agregar test de regresión (issue #456)

**Bloqueadores**
Ninguno.
```

## Common Errors to Avoid

❌ **Asking to create new page when Jira URL provided**
- Extract Jira key and query for existing page first
- DO NOT ask to create new - find the existing work log

❌ **Translating work log to Spanish**
- Work logs stay in ENGLISH
- Only the manager summary artifact is in Spanish

❌ **CRITICAL: Modifying the work log page in ANY way**
- The work log is READ-ONLY input
- DO NOT append to it
- DO NOT translate it
- DO NOT modify it
- Only READ from it

❌ **Appending summary to work log instead of creating child page**
- Use `mcp__notion__create_page` with `parent: { page_id: "work-log-id" }`
- This creates a NESTED page under the work log
- DO NOT use `append_to_page_content` - that modifies the work log

❌ **Communicating with user in Spanish**
- ALL agent ↔ user communication must be in English

❌ **Being verbose or adding unnecessary formatting**
- Keep it concise: 2-3 sentences per section MAX
- No decorative emojis, no excessive bullets

❌ **Changing content between preview and final output**
- Generate once, use that exact version for both preview and child page
- Don't rewrite or "improve" it after showing the user

❌ **Fabricating information**
- Only report what's in the sources

❌ **Copying the diff or mentioning specific lines**
- Explain the logic conceptually

❌ **Including code snippets**
- GitHub already shows the code, you synthesize the "what" and "why"

❌ **Asking for user approval**
- This is a one-shot process, generate and create immediately

❌ **Reprinting the summary to the user**
- Only provide the Notion child page URL

❌ **Proceeding without Jira ID**
- Stop and ask if missing

## Template Variables

When using this template, replace:

- `{JIRA-ID}` - The Jira issue ID extracted from properties (e.g., SYS-2110)
- `{notion-page-id}` - The UUID of the Notion page
- `{github-issue}` - The GitHub issue (if available)
- `{timestamp}` - Get via `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
- `{executive-summary}` - Synthesized from Notion log + GitHub issue
- `{achievements}` - Extracted from Notion page content
- `{context}` - Root cause and solution, conceptual
- `{next-steps}` - Future work documented in the log
- `{blockers}` - Active documented problems (can be empty)
