# Template: Stakeholder Update

## Purpose

This template guides the generation of non-technical updates for stakeholders (domain experts, product managers, QA specialists), informing them about completed work from a user perspective.

## Audience

**Non-technical stakeholders:** Product managers, domain experts, QA specialists who are not developers.

The update should:
- Translate complex technical logs into simple, clear language
- Focus on **what** was done from the user's perspective
- Explain **what** they need to test
- **Avoid all technical jargon**

## Language

**ALL agent ↔ user communication: ENGLISH**

**Final artifact output: SPANISH**

The stakeholder update itself must be in Spanish, but all questions, confirmations, and communication with the user are in English.

## Workflow

### Step 1: Gather Inputs (English)

**Ask the user:**
1. **Notion Page ID** of the completed work item

**If information is missing:**
- STOP and ASK for missing inputs (in English)
- Do not proceed without the Notion page ID

### Step 2: Analyze Work Log

1. **Fetch the Notion page**
   - Use `mcp__notion__notion-fetch` with the page ID

2. **Look for relevant sections:**
   - "Business Impact" or "Impacto al Negocio"
   - "Goal" or "Objetivo"
   - "Summary" or "Resumen"

3. **Ignore low-level details:**
   - Technical implementation
   - Specific code changes
   - Architecture details
   - File or function names

4. **Focus on user perspective:**
   - What can the user do now?
   - What bug will the user no longer see?
   - What new functionality is available?
   - What flow improved?

### Step 3: Draft Stakeholder Update in Spanish

**CRITICAL: The stakeholder update output must be in Spanish.**

**Create a simple, professional message.**

**Required format:**

```markdown
Este issue ya está resuelto. [Simple explanation from user perspective in 1-2 sentences].

[What changed for the user in 1-2 sentences].

**Para probar:**
- [Specific step 1 user can do]
- [Specific step 2 user can do]
- [Expected result they should see]

Por favor háznoslo saber si está funcionando como esperas.
```

**Content guidelines:**

- **Simple language:** Don't use terms like "OAuth", "token", "API", "validation", "conditional", etc.
- **User perspective:** Describe in terms of what the user experiences
- **Concrete test steps:** Give specific actions they can perform
- **Clear expected result:** Say what they should see if it works correctly
- **Professional tone:** No "Gracias por reportar!" (not client-like)
- **NO metadata sections:** No "Para:", "Estado:", "When released:", "Test coverage:", or ETAs

**Translation examples (technical → non-technical):**

| ❌ Technical | ✅ Non-technical |
|--------------|------------------|
| "Corregimos un bug en la lógica de renovación de tokens OAuth" | "Arreglamos un problema que causaba errores de sesión" |
| "La validación de expiración usaba operador incorrecto" | "El sistema ahora mantiene tu sesión activa correctamente" |
| "Implementamos nuevo endpoint para exportación de datos" | "Ahora puedes descargar tus datos en formato Excel" |
| "Refactorizamos el componente de autenticación" | "Mejoramos la confiabilidad del inicio de sesión" |

### Step 4: Iterate with User (English)

**CRITICAL: Do not proceed without explicit approval.**

1. Present the draft to the user (stakeholder update in Spanish)
2. Ask (in English): "Does this stakeholder update communicate the changes clearly?"
3. Make adjustments based on feedback
4. Repeat until user approves

**VERIFY:** Before proceeding, double-check that the stakeholder update is in Spanish.

### Step 5: Create Child Page with Update

**Only after user approval:**

1. **Get timestamp**
   ```bash
   TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'
   ```

2. **Create child page**
   - Parent: The Notion work log page
   - Title: `Stakeholder Update - {timestamp}`
   - Content: The approved Spanish stakeholder update
   - Use Notion's child page syntax: `<page>Stakeholder Update - {timestamp}</page>`

**Example:**
```markdown
<page>Stakeholder Update - 2025-01-04 15:45</page>
[Full approved stakeholder update in Spanish goes here]
</page>
```

### Step 6: Confirm (English)

**Notify the user:**
```
✅ Stakeholder update created: [child page URL]
```

**User can then copy the text from the child page to GitHub or other communication channels.**

## Tone Guidelines

**For agent ↔ user communication (English):**
- Clear, direct questions
- Professional but conversational
- Seek clarification when needed

**For stakeholder update artifact (Spanish):**
- **Friendly:** Use professional but warm tone
- **Simple:** Non-technical vocabulary
- **Clear:** Short, direct sentences
- **Helpful:** Provide concrete test steps
- **Professional:** Maintain courtesy and respect (no client-like "Gracias por reportar!")
- **Value-oriented:** Emphasize benefit for the user

## Content Priorities

### Include (Primary):
- What was fixed/added from user perspective
- What the user can do now (or what problem they won't see)
- Specific steps to test the change
- Expected result from tests
- Request for feedback

### Include (Secondary):
- Business context (if it helps understanding)
- Benefit or impact to user flow

### Exclude:
- Technical implementation details
- File or component names
- Development jargon (API, endpoint, token, etc.)
- Code changes
- Architecture information
- Technical metrics (tests, performance)
- Metadata sections (Para:, Estado:, When released:, Test coverage:, ETAs)
- Fabricated information not in work log

## Example Output

### Example 1: Bug Fix

```markdown
Este issue ya está resuelto. Arreglamos el problema que causaba que tu sesión se cerrara inesperadamente cuando intentabas renovar tu acceso.

Ahora cuando tu sesión esté por expirar, el sistema la renovará automáticamente sin errores ni interrupciones.

**Para probar:**
- Inicia sesión en la aplicación
- Deja la sesión abierta por más de 1 hora
- Intenta realizar alguna acción (ej. ver un reporte)
- Deberías poder continuar trabajando sin necesidad de volver a iniciar sesión

Por favor háznoslo saber si está funcionando como esperas.
```

### Example 2: New Feature

```markdown
Este issue ya está resuelto. Agregamos la funcionalidad que solicitaste para exportar datos de estudiantes a Excel.

Ahora puedes descargar la lista completa de estudiantes con toda su información en un archivo Excel que puedes abrir y editar en tu computadora.

**Para probar:**
- Ve a la sección "Estudiantes" en el menú principal
- Haz clic en el botón "Exportar" en la esquina superior derecha
- Selecciona "Formato Excel"
- Descarga el archivo y ábrelo en Excel
- Deberías ver todas las columnas de información de los estudiantes correctamente organizadas

Por favor háznoslo saber si está funcionando como esperas.
```

### Example 3: UX Improvement

```markdown
Este issue ya está resuelto. Mejoramos el proceso de carga de documentos para que sea más rápido y confiable.

Ahora cuando subas un documento, verás una barra de progreso clara y el documento se guardará correctamente sin necesidad de reintentar.

**Para probar:**
- Ve a la sección donde subes documentos
- Selecciona un archivo de tu computadora (prueba con uno de al menos 5MB)
- Observa la barra de progreso mientras se sube
- Confirma que aparece el mensaje de éxito cuando termina
- Verifica que el documento aparece en tu lista de documentos subidos

Por favor háznoslo saber si está funcionando como esperas.
```

## Common Errors to Avoid

❌ **Using technical jargon**
- "OAuth token", "API endpoint", "schema validation", etc.

❌ **Explaining how it was implemented**
- "We changed the operator on line 167"

❌ **Being vague about tests**
- "Test that it works" → Give specific steps

❌ **Forgetting to mention expected result**
- User won't know if the test was successful

❌ **Using English for the stakeholder update**
- The artifact output must be in Spanish

❌ **Communicating with user in Spanish**
- ALL agent ↔ user communication must be in English

❌ **Too formal or technical tone**
- Should be friendly and accessible (but professional, not client-like)

❌ **Publishing without user approval**
- Always iterate on the draft first

❌ **Assuming technical context**
- Explain in terms of user experience

❌ **Adding metadata sections**
- No "Para:", "Estado:", "When released:", "Test coverage:", or ETAs

❌ **Fabricating information**
- Only include what's documented in the work log

❌ **Client-like tone**
- No "Gracias por reportar!" - maintain professional colleague tone

## Template Variables

When using this template, replace:

- `{notion-page-id}` - The UUID of the Notion page
- `{timestamp}` - Get via `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'`
- `{simple-explanation}` - What was fixed/added in non-technical language
- `{user-perspective}` - What changed for the user
- `{test-steps}` - Specific, concrete actions
- `{expected-result}` - What they should see if it works
