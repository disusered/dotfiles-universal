# Template: PR Description

## Purpose

Generate technical PR descriptions in Spanish from Markdown work logs for code review.

## Audience

**Software engineers reviewing code in GitHub.**

The PR description should:
- Explain the technical changes and why they were made
- Focus on implementation details and testing
- Use technical Spanish terminology
- Be clear and actionable for code reviewers

## Language

**CRITICAL - READ CAREFULLY:**

**ALL agent ↔ user communication: ENGLISH**
**ALL work log content: ENGLISH (DO NOT TRANSLATE)**
**ONLY PR description artifact: SPANISH (technical Spanish)**

## Workflow

### Step 1: Gather Required Inputs

Ask the user (in English):
- **Work log filename** (e.g., `fix-oauth-token.md` from `dev/active/`)
- **Source branch** (e.g., `feature/fix-oauth`)
- **Target branch** (e.g., `main` or `develop`)

**If any missing: STOP and ASK**

### Step 2: Read Work Log (READ-ONLY)

**CRITICAL: The work log is READ-ONLY - you will NOT modify it**

1. Use Read tool: `dev/active/{filename}.md`
2. Extract from frontmatter:
   - **GitHub**: Issue URL (if present)
   - **Jira**: Issue URL (if present) - **DO NOT include in PR description** (internal only)
   - **Type**: bug/feature/task
   - **Priority**: 0-4
3. Read work log content:
   - Technical summary
   - Root cause analysis
   - Solution approach
   - Testing notes

### Step 3: Analyze Git Changes

**Get the actual code changes:**

```bash
# See commit history
git log origin/{target}..{source} --oneline

# See file changes
git diff origin/{target}...{source} --stat

# See detailed changes
git diff origin/{target}...{source}
```

**Extract:**
- Files modified
- Core logic changes
- Tests added/modified
- Breaking changes (if any)

### Step 4: Generate PR Description (Spanish)

**Format:**

```markdown
## Resumen

[1-2 sentences explaining what this PR does and why]

## Cambios Técnicos

- [Technical change 1 with reasoning]
- [Technical change 2 with reasoning]
- [Technical change 3 with reasoning]

## Testing

- [Test approach 1]
- [Test approach 2]
- [Manual testing performed]

## Notas para Revisión

- [Important consideration 1]
- [Important consideration 2]
- [Breaking changes or migration notes if any]
```

**Content Rules:**

✅ **DO include:**
- What changed and why
- Technical approach
- Testing performed
- GitHub issue link (if available)
- Breaking changes or migrations needed
- Important review considerations

❌ **DO NOT include:**
- Jira issue links or numbers (internal tracking - keep private)
- Work log file paths
- Internal tool references
- Commit SHAs (GitHub shows these)
- Line-by-line diff reproduction

**Tone:**
- Technical but clear Spanish
- Direct and concise
- Focus on reviewer needs

**CRITICAL - NO FOOTERS OR SIGNATURES:**
- ❌ **NEVER** add footer links like "Generated with Claude Code"
- ❌ **NEVER** add attribution, signatures, or tool credits
- ❌ **NEVER** add emojis like 🤖 or decorative elements at the end
- The PR description must end with actual content, not meta-commentary about how it was created

### Step 5: Save Artifact

**Get timestamp:**
Use current time from injected context (format: YYYY-MM-DD-HHMM)

**Save to file:**
- Path: `dev/artifacts/{work-log-name}-pr-{timestamp}.md`
- Content: The exact Spanish PR description

**Use Write tool to create the artifact file.**

### Step 6: Create PR (Optional)

**If user wants to create the PR immediately:**

1. Invoke the `gh` skill to get GitHub CLI syntax
2. Use `gh pr create`:
   ```bash
   gh pr create \
     --base {target} \
     --head {source} \
     --title "{PR title}" \
     --body-file dev/artifacts/{work-log-name}-pr-{timestamp}.md
   ```

**If user just wants the file:**
- Respond: `✅ PR description created: dev/artifacts/{filename}.md`
- **DO NOT reprint the content** (it's in the file)

### Step 7: Information Flow Security

**CRITICAL: Jira references MUST NOT leak to public GitHub.**

- ✅ **GitHub issue links:** OK to include in PR (public repo)
- ❌ **Jira issue links:** NEVER include (internal tracking)
- ❌ **Work log paths:** NEVER include (internal files)

**If work is tracked in both Jira and GitHub:**
- PR description only mentions the GitHub issue
- Jira link stays in the work log file (internal)

## Example Output

```markdown
## Resumen

Corrige error en validación de tokens OAuth que causaba rechazos incorrectos. El problema era un operador de asignación (`=`) usado en lugar de comparación (`==`).

## Cambios Técnicos

- **Corregido operador lógico** en `lib/auth/validator.py` línea 167
  - Cambio de `=` (asignación) a `==` (comparación)
  - Previene que tokens válidos sean marcados como expirados
- **Agregados tests unitarios** para validación de expiración
  - Casos: token válido, expirado, y futuro
  - Cobertura aumentó de 65% a 89%

## Testing

- 15 tests unitarios pasando (3 nuevos)
- Testing manual con tokens reales en staging
- Verificado que no afecta renovación automática de tokens

## Notas para Revisión

- Cambio es backward-compatible
- No requiere migración de datos
- Considerar backport a v2.x si es aplicable

Relacionado con #123
```

## Common Errors to Avoid

❌ **Including Jira links in PR**
- Jira is internal only, never expose to public GitHub

❌ **Translating work log to Spanish**
- Work logs stay in English, only the PR description is Spanish

❌ **Modifying the work log file**
- Work log is READ-ONLY input

❌ **Reprinting the artifact to user**
- Only provide the file path

❌ **Using English in PR description**
- PR descriptions must be in Spanish

❌ **Copying the git diff verbatim**
- Summarize conceptually, don't paste diffs
