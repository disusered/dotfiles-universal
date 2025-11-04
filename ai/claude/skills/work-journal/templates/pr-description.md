# Plantilla: Descripción de Pull Request (PR)

## Propósito

Esta plantilla guía la generación de descripciones técnicas para Pull Requests de GitHub, combinando el contexto del "por qué" (del log de Notion) con el "qué" (de los cambios en git).

## Audiencia

**Desarrolladores que revisarán el código.**

La descripción del PR debe proporcionar a los revisores todo el contexto que necesitan para entender:
- Por qué se hizo este cambio
- Qué se cambió técnicamente
- Cómo verificar que funciona
- Qué aspectos específicos revisar

## Idioma

**Español** - Toda la salida debe estar en español.

## Flujo de Trabajo

### Paso 1: Recopilar Entradas

**Pedir al usuario:**
1. **ID(s) de Página de Notion** - Todos los elementos de trabajo incluidos en este PR
2. **Rama de Origen** - Tu rama (ej. `feature/oauth-fix`)
3. **Rama de Destino** - Rama base (ej. `main` o `develop`)

**Si falta información:**
- DETENTE y pregunta por las entradas faltantes
- No procedas hasta tener al menos un ID de página de Notion y las ramas

### Paso 2: Analizar Contexto (El "Por Qué")

1. **Obtener la(s) página(s) de Notion**
   - Usa `mcp__notion__notion-fetch` con cada ID de página
   - Extrae del contenido de la página:
     - Resumen Técnico
     - Objetivo/Meta
     - Causa Raíz (para bugs)
     - Contexto relevante del negocio o técnico

2. **Identificar la justificación**
   - Por qué era necesario este trabajo
   - Qué problema resuelve
   - Qué mejora aporta

### Paso 3: Analizar Cambios (El "Qué")

1. **Inspeccionar cambios de git**
   ```bash
   # Ver el diff entre rama destino y rama origen
   git diff origin/{rama-destino}...{rama-origen}

   # Ver los commits en la rama
   git log origin/{rama-destino}..{rama-origen} --oneline
   ```

2. **Crear resumen de alto nivel**
   - ¿Qué archivos se modificaron?
   - ¿Qué componentes/servicios se afectaron?
   - ¿Qué patrones o enfoques se usaron?

3. **Categorizar cambios**
   - Nuevas funcionalidades añadidas
   - Bugs corregidos
   - Refactorizaciones realizadas
   - Tests agregados/modificados
   - Documentación actualizada

**Nota:** No copies el diff completo. Sintetiza los cambios clave.

### Paso 4: Generar Borrador de Descripción del PR

**Combina el "por qué" y el "qué" en una descripción estructurada.**

**Formato requerido:**

```markdown
## Resumen

[1-2 párrafos que explican qué hace este PR y por qué era necesario]

## Trabajo Relacionado

- Notion: [Título de la página](https://notion.so/...)
- Jira: [ISSUE-123](https://odasoftmx.atlassian.net/browse/ISSUE-123) _(si aplica)_
- GitHub Issue: [#456](https://github.com/user/repo/issues/456) _(si aplica)_

## Cambios Realizados

### [Categoría 1: ej. Corrección de Bugs]
- **[Archivo/Componente]**: [Descripción del cambio y por qué]
- **[Archivo/Componente]**: [Descripción del cambio y por qué]

### [Categoría 2: ej. Nuevas Funcionalidades]
- **[Archivo/Componente]**: [Descripción del cambio y por qué]

### [Categoría 3: ej. Tests]
- **[Archivo]**: [Qué se agregó/modificó para testing]

## Contexto Técnico

[Detalles técnicos del log de Notion que explican por qué era necesario el cambio]

**Causa Raíz** _(para bugs):_
[Explicación técnica de qué causó el problema]

**Enfoque de Solución:**
[Por qué se eligió este enfoque vs otras opciones]

**Impacto:**
[Qué mejora esto: rendimiento, seguridad, mantenibilidad, etc.]

## Plan de Pruebas

[Cómo se verificó que los cambios funcionan]

- [ ] Tests unitarios pasando
- [ ] Tests de integración pasando _(si aplica)_
- [ ] Verificación manual: [pasos específicos]
- [ ] [Otros criterios de aceptación]

## Notas para Revisores

[Opcional: Aspectos específicos que los revisores deben verificar]

- **Seguridad:** [Consideraciones de seguridad, si aplica]
- **Rendimiento:** [Impactos de rendimiento, si aplica]
- **Compatibilidad:** [Cambios que rompen compatibilidad, si aplica]
- **Áreas de enfoque:** [Archivos o lógica específicos para revisar con cuidado]

---

🤖 Generado con [Claude Code](https://claude.com/claude-code)
```

### Paso 5: Iterar con el Usuario

**CRÍTICO: No procedas sin aprobación explícita.**

1. Presenta el borrador al usuario
2. Pregunta: "¿Esta descripción del PR captura correctamente los cambios? ¿Alguna modificación necesaria?"
3. Realiza ajustes según retroalimentación
4. Repite hasta que el usuario apruebe

### Paso 6: Crear el PR en GitHub

**Solo después de la aprobación del usuario:**

1. **Verificar estado de git**
   ```bash
   # ¿La rama actual rastrea una rama remota?
   git rev-parse --abbrev-ref --symbolic-full-name @{u}

   # ¿Está actualizada con el remoto?
   git status
   ```

2. **Push si es necesario**
   ```bash
   # Si la rama no existe en el remoto o no está actualizada
   git push -u origin {rama-origen}
   ```

3. **Crear PR usando GitHub CLI**
   ```bash
   gh pr create --base {rama-destino} --head {rama-origen} --title "{título}" --body "$(cat <<'EOF'
   [Descripción completa aprobada del PR aquí]
   EOF
   )"
   ```

**Importante:** Usa un HEREDOC para el body del PR para garantizar formato correcto.

### Paso 7: Confirmar

**Notificar al usuario:**
```
✅ PR creado exitosamente: [URL del PR]
```

**Proporciona el URL del PR para que el usuario pueda verlo.**

## Directrices de Tono

- **Técnico:** Asume que los revisores son desarrolladores con contexto del proyecto
- **Detallado:** Incluye suficiente contexto técnico para entender el "por qué"
- **Enfocado en código:** Menciona archivos específicos, componentes, patrones
- **Directo:** Ve al grano, pero no omitas contexto importante
- **Idioma:** Todo en español
- **Profesional:** Mantén tono formal de documentación técnica

## Prioridades de Contenido

### Incluir (Primario):
- Razón del cambio (por qué era necesario)
- Resumen de cambios clave (qué archivos/componentes)
- Causa raíz (para bugs)
- Enfoque de solución
- Plan de pruebas
- Enlaces a trabajo relacionado (Notion, Jira, GitHub)

### Incluir (Secundario):
- Notas específicas para revisores
- Consideraciones de seguridad/rendimiento
- Cambios que rompen compatibilidad
- Deuda técnica introducida/resuelta

### Excluir:
- Diff completo de código (GitHub lo muestra)
- Lista de cada archivo modificado (GitHub lo muestra)
- Historial detallado de commits (debe ser parte del log de git)
- Contexto obvio que todos los desarrolladores conocen

## Ejemplo de Salida

```markdown
## Resumen

Este PR corrige un bug crítico en el flujo de renovación de tokens OAuth que causaba errores `invalid_grant` para los usuarios. El problema se originó por un operador de asignación (`=`) usado incorrectamente en lugar de un operador de comparación (`==`) en la verificación de expiración del token, lo que marcaba los tokens como expirados inmediatamente después de la creación.

## Trabajo Relacionado

- Notion: [Fix OAuth Token Refresh Bug](https://www.notion.so/Fix-OAuth-Token-Refresh-Bug-abc123...)
- Jira: [SYS-2110](https://odasoftmx.atlassian.net/browse/SYS-2110)
- GitHub Issue: [#123](https://github.com/odasoftmx/app/issues/123)

## Cambios Realizados

### Corrección de Bugs
- **src/auth/oauth.js (línea 167)**: Corregido operador de asignación a comparación en verificación de expiración del token. Cambio de `if (token.expires_at = Date.now())` a `if (token.expires_at <= Date.now())`. Se usó `<=` en lugar de `==` para manejar defensivamente el caso límite de timestamp exacto.

### Tests
- **tests/auth/oauth.test.js**: Todos los tests existentes ahora pasan con la corrección aplicada.

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

## Plan de Pruebas

- [x] Tests unitarios pasando (todos los 15 tests en oauth.test.js)
- [x] Verificación manual: Creado token, esperado tiempo de expiración, confirmado que no se renueva prematuramente
- [x] Regresión: Verificado que tokens válidos no se renuevan antes de la expiración

## Notas para Revisores

- **Seguridad:** Este cambio no introduce nuevos vectores de seguridad. De hecho, reduce llamadas innecesarias a la API de OAuth.
- **Áreas de enfoque:** Por favor revisen la línea 167 en `src/auth/oauth.js` cuidadosamente para confirmar que la lógica de comparación es correcta.
- **Trabajo futuro:** Se creó [#456](https://github.com/odasoftmx/app/issues/456) para agregar test de regresión específico para este bug de operador y agregar este archivo a la configuración de ESLint.

---

🤖 Generado con [Claude Code](https://claude.com/claude-code)
```

## Errores Comunes a Evitar

❌ **Copiar el diff completo de git**
- Sintetiza los cambios clave, no pegues el diff

❌ **Omitir el "por qué"**
- Los revisores necesitan contexto, no solo una lista de cambios

❌ **Crear PR sin aprobación del usuario**
- Siempre itera en el borrador primero

❌ **Olvidar push de la rama**
- Verifica que la rama esté en el remoto antes de crear el PR

❌ **Usar inglés**
- Toda la salida debe estar en español

❌ **Descripción vaga o genérica**
- Sé específico sobre archivos, componentes, y razones

❌ **Omitir enlaces a trabajo relacionado**
- Siempre enlaza a la página de Notion, y Jira/GitHub si aplica

## Variables de Plantilla

Al usar esta plantilla, reemplaza:

- `{rama-origen}` - Rama con los cambios (ej. `feature/oauth-fix`)
- `{rama-destino}` - Rama base para merge (ej. `main`)
- `{página-notion-id}` - ID de la página de Notion con el log de trabajo
- `{título}` - Título breve del PR (ej. "Corregir bug de renovación de token OAuth")
- `{descripción}` - La descripción completa y aprobada del PR
