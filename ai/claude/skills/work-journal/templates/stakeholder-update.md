# Template: Stakeholder Update

## Purpose

Generate non-technical status updates in Spanish for external stakeholders from Markdown work logs.

## Audience

**Non-technical stakeholders (product managers, business owners, clients).**

The update should:
- Focus on user-facing impact and business value
- Avoid technical jargon and implementation details
- Be clear about what changed from the user perspective
- Highlight progress and next steps

## Language

**CRITICAL - READ CAREFULLY:**

**ALL agent ↔ user communication: ENGLISH**
**ALL work log content: ENGLISH (DO NOT TRANSLATE)**
**ONLY stakeholder update artifact: SPANISH (non-technical business Spanish)**

## Critical Rules

### RULE 1: NON-TECHNICAL LANGUAGE

This is for **non-technical stakeholders**. Avoid technical terms.

❌ **AVOID:**
- Technical jargon ("OAuth", "API", "authentication token")
- Code references
- System architecture details
- Implementation specifics

✅ **USE:**
- User-facing impact ("login errors", "slow performance")
- Business outcomes ("improved reliability", "faster checkout")
- Plain Spanish ("el sistema", "la aplicación", "los usuarios")

### RULE 2: EXTERNAL AUDIENCE - NO INTERNAL REFERENCES

**CRITICAL: This is a public/external update.**

DO NOT include:
- ❌ Jira issue links or numbers
- ❌ Internal work log references
- ❌ Internal tool names
- ❌ GitHub issue numbers (unless repo is public AND stakeholder has context)
- ❌ Technical debugging details
- ❌ Code snippets or file paths

✅ **DO include:**
- User-visible changes
- Business impact
- Timeline for users
- Next user-facing features

### RULE 3: PROFESSIONAL FORMATTING

- ❌ DO NOT use decorative emojis
- ❌ DO NOT use casual language
- ✅ DO maintain professional business tone
- ✅ DO use plain Spanish

### RULE 4: DO NOT FABRICATE

Only report what's in the work log or GitHub issue. Do not invent:
- Metrics not documented
- Dates not specified
- Features not mentioned
- Business impact not stated

## Workflow

### Step 1: Gather Required Inputs

Ask the user (in English):
- **Work log filename** (e.g., `fix-oauth-token.md` from `dev/active/`)

**If missing: STOP and ASK**

### Step 2: Read Work Log (READ-ONLY)

**CRITICAL: The work log is READ-ONLY - you will NOT modify it**

1. Use Read tool: `dev/active/{filename}.md`
2. Extract from frontmatter:
   - **GitHub**: Issue URL (if available and public)
   - **Type**: bug/feature/task
   - **Priority**: 0-4
3. Read work log content:
   - Problem from user perspective
   - Solution impact
   - Testing performed
   - Next steps

### Step 3: Get GitHub Context (if available and public)

**If GitHub URL found in frontmatter AND repo is public:**

1. Use `gh issue view` to read the GitHub issue
2. Extract **user-facing context**:
   - Original problem report
   - User impact
   - Expected behavior

**If repo is private or internal:** Skip GitHub, use work log only.

### Step 4: Analyze for User Impact

**Focus on translating technical work into business value:**

1. **What was the user problem?**
   - What were users experiencing?
   - How did it affect their work?

2. **What did we fix?**
   - How does this improve the user experience?
   - What can users do now that they couldn't before?

3. **What's the business impact?**
   - Improved reliability/performance?
   - Reduced errors?
   - New capability?

4. **What's next?**
   - Follow-up improvements mentioned
   - Future features planned

### Step 5: Generate Stakeholder Update (Spanish)

**CRITICAL: The update must be in non-technical Spanish.**

**CONCISENESS RULE:**
- 2-3 sentences per section MAX
- Clear, simple language
- Focus on "what" and "why", not "how"

**Format:**

```markdown
## Actualización: [Brief title]

**Resumen**
[1-2 sentences explaining what was fixed/improved from user perspective]

**Impacto para Usuarios**

- [User benefit 1]
- [User benefit 2]
- [User benefit 3]

**Estado Actual**
[Current status: testing, deployed, in progress]

**Próximos Pasos**

- [Next user-facing improvement, if planned]
- [Timeline if available]
```

**Tone:**
- Professional business Spanish
- Non-technical but informative
- Focus on user and business value

### Step 6: Save Artifact

**Get timestamp:**
Use current time from injected context (format: YYYY-MM-DD-HHMM)

**Save to file:**
- Path: `dev/artifacts/{work-log-name}-stakeholder-{timestamp}.md`
- Content: The exact Spanish stakeholder update

**Use Write tool to create the artifact file.**

### Step 7: Post to GitHub or Share (Optional)

**If user wants to post to GitHub issue:**

1. Invoke the `gh` skill to get GitHub CLI syntax
2. Use `gh issue comment`:
   ```bash
   gh issue comment {issue-number} \
     --body-file dev/artifacts/{work-log-name}-stakeholder-{timestamp}.md
   ```

**If user just wants the file:**
- Respond: `✅ Stakeholder update created: dev/artifacts/{filename}.md`
- **DO NOT reprint the content** (it's in the file)

## Example Output

```markdown
## Actualización: Mejora en Sistema de Acceso

**Resumen**
Se corrigió un error que causaba problemas de login intermitentes para usuarios. El sistema ahora valida correctamente las sesiones activas.

**Impacto para Usuarios**

- Reducción de errores de login (40% menos llamadas fallidas)
- Experiencia de inicio de sesión más confiable
- Usuarios ya no necesitan reintentar múltiples veces

**Estado Actual**
Implementado y verificado en ambiente de pruebas. Despliegue a producción programado para esta semana.

**Próximos Pasos**

- Monitoreo de métricas de login post-despliegue
- Mejora adicional en velocidad de autenticación (próximo sprint)
```

## Common Errors to Avoid

❌ **Using technical jargon**
- Keep language simple and user-focused
- Avoid terms like "OAuth", "API", "token validation"

❌ **Including internal references**
- NO Jira links, work log paths, or internal tool names
- This is an external/public update

❌ **Including GitHub issue numbers without context**
- Only if repo is public AND stakeholder understands GitHub

❌ **Translating work log to Spanish**
- Work logs stay in ENGLISH
- Only the stakeholder update artifact is in Spanish

❌ **Modifying the work log file**
- Work log is READ-ONLY input

❌ **Communicating with user in Spanish**
- ALL agent ↔ user communication must be in English

❌ **Reprinting the update to the user**
- Only provide the artifact file path

❌ **Fabricating metrics or dates**
- Only report what's documented in sources

❌ **Explaining the technical fix**
- Focus on user impact, not implementation details
