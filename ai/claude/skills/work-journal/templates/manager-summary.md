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

**ALL agent ↔ user communication: ENGLISH**

**Final artifact output: SPANISH (formal business Spanish)**

The manager summary itself must be in Spanish, but all questions, confirmations, and communication with the user are in English.

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

### RULE 3: NO GITHUB DUPLICATION

DO NOT include:
- ❌ Code snippets
- ❌ Line numbers
- ❌ Commit SHAs
- ❌ Links to git files

Notion properties and GitHub UI already show this. Your job is to synthesize, not copy.

### RULE 4: PROFESSIONAL FORMATTING

- ❌ DO NOT use decorative emojis in headings
- ❌ DO NOT use casual headings (e.g., "Done", "All good!")
- ✅ DO use emojis in bullet lists for clarity (optional)
- ✅ DO maintain professional report tone

### RULE 5: NO INVENTED DATES

DO NOT include completion dates (e.g., "Completed on January 4").

Dates are already in Notion properties and GitHub. Don't invent or assume undocumented dates.

## Workflow

### Step 1: PRIMARY DIRECTIVE - Find Notion Page ID (English)

**Your first and only job is to find the Notion Page ID.**

1. Look in the user's most recent message
2. Look for a Notion Page ID (UUID) or URL

**If NOT clearly provided:**
- **STOP** immediately
- **ASK** (in English) for the Notion Page ID only
- Example: "What's the Notion page ID for the work log?"

**Do not proceed to any other step until you have this ID.**

### Step 2: Get Page Data (CRITICAL)

**Once you have the Page ID:**

1. **Get the page object** to read its **properties**
   - Use `mcp__notion__notion-fetch` with the page ID

2. **Extract required properties:**
   - **Jira ID:** Extract the `Jira issue #` URL
     - If **empty**, **STOP** and ask the user (in English) for the Jira ID
     - Example: "I need the Jira ID for this work (e.g., PROJ-123). Can you provide it?"
   - **GitHub ID:** Extract the `Github issue #` URL (if available)

### Step 3: Get GitHub Context (if available)

**If a `Github issue #` URL was found:**

1. Use `mcp__github__issue_read` to read the GitHub issue
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

**Formato requerido:**

```markdown
---

## Resumen de Jira (para {JIRA-ID})

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

**Create a child page with this Spanish summary text.**

1. **Get timestamp**
   ```bash
   TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'
   ```

2. **Create child page**
   - Parent: The Notion work log page
   - Title: `Manager Summary - {timestamp}`
   - Content: The Spanish manager summary
   - Use Notion's child page syntax: `<page>Manager Summary - {timestamp}</page>`

- **DO NOT ask for approval.** This is a one-shot action: generate and create immediately.
- Use the Jira ID you found in Step 2 for the summary heading.

### Step 6: Final Step (English)

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

### Include (Primary):
- Business impact
- Metrics and data
- Progress and timeline (only if documented)
- Concrete next steps
- Blockers with required actions

### Include (Secondary):
- Technical approach (high level only)
- Root cause (conceptual, no code)
- Important technical decisions

### Exclude:
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

## Resumen de Jira (para SYS-2110)

**Resumen Ejecutivo**
Se corrigió un bug crítico en el sistema de autenticación OAuth que causaba errores `invalid_grant` para usuarios al intentar renovar tokens de acceso. El problema afectaba aproximadamente 15% de las sesiones de usuario diariamente.

**Logros Clave**
- Identificación y corrección de bug lógico en verificación de expiración de tokens (operador incorrecto causaba evaluación prematura)
- Validación completa con 15 tests unitarios pasando exitosamente
- Eliminación de reintentos innecesarios de renovación, reduciendo llamadas a API de OAuth en ~40%

**Contexto Técnico**
El sistema de autenticación usaba un operador de asignación en lugar de comparación en la validación de expiración de tokens. Esto causaba que todos los tokens se marcaran como expirados inmediatamente después de su creación, forzando intentos de renovación constantes que fallaban con error `invalid_grant`.

La solución corrigió la lógica de comparación para evaluar correctamente la expiración del token, usando un operador de comparación defensivo que maneja casos límite de timestamp. Este cambio es backward-compatible y no requiere migraciones.

**Siguiente Pasos**
- Rollout de fix a producción esta semana (esperando aprobación de QA)
- Agregar test de regresión específico para prevenir bug similar en futuro (issue #456 creado)
- Incluir archivo en configuración de ESLint para detección automática de este tipo de errores

**Bloqueadores**
Ninguno. El trabajo está completo y listo para merge.
```

## Common Errors to Avoid

❌ **Fabricating information**
- Only report what's in the sources

❌ **Copying the diff or mentioning specific lines**
- Explain the logic conceptually

❌ **Including code snippets**
- GitHub already shows the code, you synthesize the "what" and "why"

❌ **Using casual headings or decorative emojis**
- Maintain professional report tone

❌ **Inventing dates**
- Don't say "Completed on..." without documented date

❌ **Creating "Related Tickets" section**
- Main tickets are already in Notion properties

❌ **Asking for user approval**
- This is a one-shot process, generate and create immediately

❌ **Reprinting the summary to the user**
- Only provide the Notion child page URL

❌ **Proceeding without Jira ID**
- Stop and ask if missing

❌ **Using English for the manager summary**
- The artifact output must be in Spanish

❌ **Communicating with user in Spanish**
- ALL agent ↔ user communication must be in English

❌ **Forgetting to verify Spanish output**
- Double-check the manager summary is in Spanish before proceeding

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
