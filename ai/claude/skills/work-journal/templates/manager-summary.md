# Template: Manager Summary

## Purpose

Generate conceptual technical summaries in Spanish for technical managers from Markdown work logs.

## Audience

**Technical manager who understands engineering concepts.**

The summary should:
- Explain the logic of the fix, not paste the diff
- Focus on progress, metrics, and business impact
- Use high-level technical concepts (no implementation details)
- Be actionable (next steps, blockers)

## Language

**CRITICAL - READ CAREFULLY:**

**ALL agent ↔ user communication: ENGLISH**
**ALL work log content: ENGLISH (DO NOT TRANSLATE)**
**ONLY manager summary artifact: SPANISH (formal business Spanish)**

## Critical Rules

### RULE 1: DO NOT FABRICATE

Your **only** task is to synthesize information from your sources (work log, GitHub issue).

❌ **DO NOT** invent:
- Metrics not in the sources
- Technical details not mentioned
- Dates or timelines not specified
- Next steps not documented

✅ **DO** summarize:
- Explicit information in the work log
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
- ❌ GitHub issue numbers (already in frontmatter)
- ❌ Jira issue numbers (already in frontmatter)
- ❌ Commit messages (visible in git log)
- ❌ PR descriptions (visible in GitHub)
- ❌ File change lists (visible in git diff)

**Your job is to SYNTHESIZE the "why" and "impact", not COPY the "what" from other tools.**

### RULE 4: PROFESSIONAL FORMATTING

- ❌ DO NOT use decorative emojis in headings or anywhere
- ❌ DO NOT use casual headings (e.g., "Done", "All good!")
- ✅ DO maintain professional report tone
- ✅ DO use plain text throughout

### RULE 5: NO INVENTED DATES

DO NOT include completion dates (e.g., "Completed on January 4").

Dates are already in work log frontmatter and GitHub. Don't invent or assume undocumented dates.

## Workflow

### Step 1: Gather Required Inputs

Ask the user (in English):
- **Work log filename** (e.g., `fix-oauth-token.md` from `dev/active/`)
- **Jira ID** (if not in work log frontmatter)

**If work log filename missing: STOP and ASK**

### Step 2: Read Work Log (READ-ONLY)

**CRITICAL: The work log is READ-ONLY - you will NOT modify it**

1. Use Read tool: `dev/active/{filename}.md`
2. Extract from frontmatter:
   - **Jira**: Issue URL (required for manager summary heading)
   - **GitHub**: Issue URL (if available)
   - **Type**: bug/feature/task
   - **Priority**: 0-4
3. Read work log content:
   - Context and problem definition
   - Technical root cause
   - Solution applied
   - Metrics/data
   - Next steps
   - Blockers

**If Jira URL missing from frontmatter:**
- STOP and ask user (in English): "I need the Jira ID for this work (e.g., PROJ-123). Can you provide it?"

### Step 3: Get GitHub Context (if available)

**If GitHub URL found in frontmatter:**

1. Use `gh issue view` to read the GitHub issue
2. Extract the **original problem definition**:
   - Reported bug description
   - Expected vs actual behavior
   - User impact
   - Business context

**If NO GitHub issue:** Proceed with work log only.

### Step 4: Analyze Work Log

**Extract:**

1. **Context:**
   - What system/component?
   - What user flow?
   - What type of problem? (bug, feature, improvement)

2. **Technical root cause:**
   - What caused the problem? (logic bug, race condition, undefined variable)
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

### Step 5: Generate Manager Summary (Spanish)

**CRITICAL: The manager summary output must be in Spanish.**

**CONCISENESS RULE:**
- 2-3 sentences per section MAX
- No bullet lists longer than 3 items
- Clear, direct language - no fluff
- If you can say it in 10 words, don't use 20

**Format:**

```markdown
## {JIRA-ID}

**Resumen Ejecutivo**
[1-2 sentences about general progress. Focus on what was accomplished and impact.]

**Logros Clave**

- [Achievement 1 with metric, if available]
- [Achievement 2 with metric, if available]
- [Achievement 3 with business or technical impact]

**Contexto Técnico**
[Conceptual explanation of root cause and solution. No code, no line numbers, just logic.]

**Siguiente Pasos**

- [Next high-priority work, if documented]
- [Next medium-priority work, if documented]

**Bloqueadores**
[Only if there are documented blockers. Include impact and required action.]

- [Blocker with impact + necessary action]
```

### Step 6: Save Artifact

**Get timestamp:**
```bash
TZ='America/Tijuana' date '+%Y-%m-%d-%H%M'
```

**Save to file:**
- Path: `dev/artifacts/{work-log-name}-manager-{timestamp}.md`
- Content: The exact Spanish manager summary

**Use Write tool to create the artifact file.**

### Step 7: Post to Jira (Optional)

**If user wants to post to Jira:**

1. Invoke the `jira` skill to get acli syntax
2. Use `acli jira workitem comment create`:
   ```bash
   acli jira workitem comment create \
     --key "{JIRA-ID}" \
     --body-file dev/artifacts/{work-log-name}-manager-{timestamp}.md
   ```

**If user just wants the file:**
- Respond: `✅ Manager summary created: dev/artifacts/{filename}.md`
- **DO NOT reprint the content** (it's in the file)

## Example Output

```markdown
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

❌ **Translating work log to Spanish**
- Work logs stay in ENGLISH
- Only the manager summary artifact is in Spanish

❌ **Modifying the work log file**
- Work log is READ-ONLY input
- DO NOT append to it
- DO NOT translate it
- Only READ from it

❌ **Communicating with user in Spanish**
- ALL agent ↔ user communication must be in English

❌ **Being verbose or adding unnecessary formatting**
- Keep it concise: 2-3 sentences per section MAX
- No decorative emojis, no excessive bullets

❌ **Changing content between preview and final output**
- Generate once, use that exact version for both preview and file

❌ **Fabricating information**
- Only report what's in the sources

❌ **Copying the diff or mentioning specific lines**
- Explain the logic conceptually

❌ **Including code snippets**
- GitHub already shows the code, you synthesize the "what" and "why"

❌ **Reprinting the summary to the user**
- Only provide the artifact file path

❌ **Proceeding without Jira ID**
- Stop and ask if missing
