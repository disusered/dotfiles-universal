# Template: Pull Request (PR) Description

## Purpose

This template guides the generation of technical PR descriptions for GitHub, combining the "why" context (from Notion log) with the "what" (from git changes).

## Audience

**Developers who will review the code.**

The PR description should provide reviewers with all the context they need to understand:
- Why this change was made
- What was changed technically
- How to verify it works
- What specific aspects to review

## Language

**ALL agent ↔ user communication: ENGLISH**

**Final artifact output: SPANISH**

The PR description itself must be in Spanish, but all questions, confirmations, and communication with the user are in English.

## Workflow

### Step 1: Gather Inputs (English)

**Ask the user:**
1. **Notion Page ID(s)** - All work items included in this PR
2. **Source Branch** - Your branch (e.g., `feature/oauth-fix`)
3. **Target Branch** - Base branch (e.g., `main` or `develop`)

**If information is missing:**
- STOP and ASK for missing inputs (in English)
- Do not proceed until you have at least one Notion page ID and the branches

### Step 2: Analyze Context (The "Why")

1. **Fetch Notion page(s)**
   - Use `mcp__notion__notion-fetch` with each page ID
   - Extract from page content:
     - Technical Summary
     - Goal/Objective
     - Root Cause (for bugs)
     - Relevant business or technical context

2. **Identify justification**
   - Why this work was necessary
   - What problem it solves
   - What improvement it brings

### Step 3: Analyze Changes (The "What")

1. **Inspect git changes**
   ```bash
   # View diff between target and source branches
   git diff origin/{target-branch}...{source-branch}

   # View commits in the branch
   git log origin/{target-branch}..{source-branch} --oneline
   ```

2. **Understand the changes conceptually**
   - What was the goal/objective?
   - What approach was taken?
   - Why was this approach chosen?

**CRITICAL:**
- **NO line numbers** - They're meaningless without commit context
- **NO file lists** - The diff already shows this
- **NO "what changed"** - The diff shows this
- **FOCUS ON "WHY"** - Context, reasoning, decisions

### Step 4: Draft PR Description in Spanish

**CRITICAL: The PR description output must be in Spanish.**

**Combine the "why" and "what" into a structured description.**

**Formato requerido:**

```markdown
## Resumen

[1-2 párrafos que explican qué hace este PR y por qué era necesario]

## Trabajo Relacionado

- Notion: [Título de la página](https://notion.so/...)
- Jira: [ISSUE-123](https://odasoftmx.atlassian.net/browse/ISSUE-123) _(si aplica)_
- GitHub Issue: [#456](https://github.com/user/repo/issues/456) _(si aplica)_

## Contexto Técnico

[Detalles técnicos del log de Notion que explican por qué era necesario el cambio]

**Causa Raíz** _(para bugs):_
[Explicación técnica de qué causó el problema]

**Enfoque de Solución:**
[Por qué se eligió este enfoque vs otras opciones]

**Impacto:**
[Qué mejora esto: rendimiento, seguridad, mantenibilidad, etc.]

## Notas para Revisores

[Opcional: Aspectos específicos que los revisores deben verificar]

- **Seguridad:** [Consideraciones de seguridad, si aplica]
- **Rendimiento:** [Impactos de rendimiento, si aplica]
- **Compatibilidad:** [Cambios que rompen compatibilidad, si aplica]
- **Áreas de enfoque:** [Archivos o lógica específicos para revisar con cuidado]

---

🤖 Generado con [Claude Code](https://claude.com/claude-code)
```

### Step 5: Iterate with User (English)

**CRITICAL: Do not proceed without explicit approval.**

1. Present the draft to the user (PR description in Spanish)
2. Ask (in English): "Does this PR description capture the changes correctly? Any modifications needed?"
3. Make adjustments based on feedback
4. Repeat until user approves

**VERIFY:** Before proceeding, double-check that the PR description is in Spanish.

### Step 6: Create Child Page with PR Text

**Only after user approval:**

1. **Get timestamp**
   ```bash
   TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'
   ```

2. **Create child page**
   - Parent: The Notion work log page
   - Title: `PR Description - {timestamp}`
   - Content: The approved Spanish PR description
   - Use Notion's child page syntax: `<page>PR Description - {timestamp}</page>`

**Example:**
```markdown
<page>PR Description - 2025-01-04 14:30</page>
[Full approved PR description in Spanish goes here]
</page>
```

### Step 7: Confirm (English)

**Notify the user:**
```
✅ PR description created: [child page URL]
```

**User can then copy the text from the child page to GitHub when creating the PR.**

## Tone Guidelines

**For agent ↔ user communication (English):**
- Clear, direct questions
- Professional but conversational
- Seek clarification when needed

**For PR description artifact (Spanish):**
- **Technical:** Assume reviewers are developers with project context
- **Detailed:** Include enough technical context to understand the "why"
- **Code-focused:** Mention specific files, components, patterns
- **Direct:** Get to the point, but don't omit important context
- **Professional:** Maintain formal technical documentation tone

## Content Priorities

### Include (Primary):
- Reason for the change (why it was necessary)
- Summary of key changes (which files/components)
- Root cause (for bugs)
- Solution approach
- Test plan
- Links to related work (Notion, Jira, GitHub)

### Include (Secondary):
- Specific notes for reviewers
- Security/performance considerations
- Breaking changes
- Technical debt introduced/resolved

### Exclude (NEVER include these):
- ❌ **Line numbers** (meaningless without commit hash)
- ❌ **File-by-file change lists** (redundant with diff)
- ❌ **Code snippets from diff** (already in GitHub)
- ❌ **"Cambios Realizados" section** (redundant)
- ❌ **Testing instructions for QA** (condescending)
- ❌ **List of modified files** (GitHub shows this)
- ❌ **Commit history** (git log shows this)
- ❌ **Fabricated information** (only describe what you did)

## Example Output

```markdown
## Resumen

Este PR corrige un bug crítico en el flujo de renovación de tokens OAuth que causaba errores `invalid_grant` para los usuarios. El problema se originó por un operador de asignación (`=`) usado incorrectamente en lugar de un operador de comparación (`<=`) en la verificación de expiración del token, lo que marcaba los tokens como expirados inmediatamente después de la creación.

## Trabajo Relacionado

- Notion: [Fix OAuth Token Refresh Bug](https://www.notion.so/Fix-OAuth-Token-Refresh-Bug-abc123...)
- Jira: [SYS-2110](https://odasoftmx.atlassian.net/browse/SYS-2110)
- GitHub Issue: [#123](https://github.com/odasoftmx/app/issues/123)

## Contexto Técnico

El bug se introdujo durante una refactorización de manejo de errores donde se consolidaron múltiples verificaciones de expiración. El operador de asignación (`=`) siempre evalúa como verdadero en JavaScript, causando que la lógica de renovación se ejecutara inmediatamente después de cada creación de token.

**Causa Raíz:**
Operador de asignación (`=`) en lugar de comparación (`==` o `<=`) en verificación condicional. Este es un error común de JavaScript que los linters modernos normalmente detectan, pero el archivo no estaba incluido en la configuración de ESLint.

**Enfoque de Solución:**
Se eligió `<=` sobre `==` porque proporciona comportamiento más robusto cuando los timestamps son exactamente iguales (caso límite poco probable pero posible). Este cambio es backward-compatible y no requiere migraciones.

**Impacto:**
- Seguridad: Previene intentos innecesarios de renovación que podrían causar agotamiento de rate limit
- Experiencia del usuario: Elimina errores `invalid_grant` que confunden a los usuarios
- Confiabilidad: Los tokens ahora se manejan correctamente durante su ciclo de vida completo

## Notas para Revisores

- **Seguridad:** Este cambio no introduce nuevos vectores de seguridad. De hecho, reduce llamadas innecesarias a la API de OAuth.
- **Trabajo futuro:** Se creó [#456](https://github.com/odasoftmx/app/issues/456) para agregar test de regresión específico para este bug de operador y agregar este archivo a la configuración de ESLint.

---

🤖 Generado con [Claude Code](https://claude.com/claude-code)
```

## Common Errors to Avoid

❌ **Including line numbers**
- Line numbers are meaningless without commit context. NEVER include them.

❌ **Creating a "Cambios Realizados" section**
- This duplicates information in the diff. Focus on WHY, not WHAT.

❌ **Listing modified files**
- The diff already shows this. Redundant and verbose.

❌ **Adding testing instructions**
- Condescending. QA knows how to test. Only describe WHAT was fixed.

❌ **Copying code from the diff**
- The diff is already there. Don't repeat it.

❌ **Omitting the "why"**
- Reviewers need context: root cause, reasoning, decisions

❌ **Creating child page without user approval**
- Always iterate on the draft first

❌ **Using English for the PR description**
- The artifact output must be in Spanish

❌ **Communicating with user in Spanish**
- ALL agent ↔ user communication must be in English

❌ **Omitting links to related work**
- Always link to Notion page, and Jira/GitHub if applicable

❌ **Fabricating information**
- Only describe what actually happened. Don't make shit up.

## Template Variables

When using this template, replace:

- `{source-branch}` - Branch with changes (e.g., `feature/oauth-fix`)
- `{target-branch}` - Base branch for merge (e.g., `main`)
- `{notion-page-id}` - ID of the Notion page with work log
- `{timestamp}` - Get via `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
- `{pr-description}` - The full approved PR description in Spanish
