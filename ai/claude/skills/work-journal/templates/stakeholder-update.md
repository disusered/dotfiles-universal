# Plantilla: Actualización para Stakeholder

## Propósito

Esta plantilla guía la generación de actualizaciones no técnicas para issues de GitHub, informando a expertos del dominio (no desarrolladores) sobre una resolución para que puedan realizar Quality Assurance (QA).

## Audiencia

**Stakeholders no técnicos:** Product managers, domain experts, QA specialists que no son desarrolladores.

La actualización debe:
- Traducir logs técnicos complejos a lenguaje simple y claro
- Enfocarse en **qué** se hizo desde la perspectiva del usuario
- Explicar **qué** necesitan probar
- **Evitar toda jerga técnica**

## Idioma

**Español** - Toda la salida debe estar en español.

## Flujo de Trabajo

### Paso 1: Identificar Entradas

**Pedir al usuario:**
1. **ID de Página de Notion** del elemento de trabajo completado
2. **Número de Issue de GitHub** (ej. "#42")

**Si falta información:**
- DETENTE y pregunta por las entradas faltantes
- No procedas sin ambas entradas

### Paso 2: Analizar Log de Trabajo

1. **Obtener la página de Notion**
   - Usa `mcp__notion__notion-fetch` con el ID de página

2. **Buscar secciones relevantes:**
   - "Impacto al Negocio" o "Business Impact"
   - "Objetivo" o "Goal"
   - "Resumen" o "Summary"

3. **Ignorar detalles de bajo nivel:**
   - Implementación técnica
   - Cambios de código específicos
   - Detalles de arquitectura
   - Nombres de archivos o funciones

4. **Enfocarse en perspectiva del usuario:**
   - ¿Qué puede hacer ahora el usuario?
   - ¿Qué bug ya no verá el usuario?
   - ¿Qué funcionalidad nueva está disponible?
   - ¿Qué flujo mejoró?

### Paso 3: Generar Borrador de Respuesta

**Crea una respuesta simple y amigable.**

**Formato requerido:**

```markdown
Hola [Nombre del Stakeholder],

Este issue ya está resuelto. [Explicación simple de lo que se arregló desde la perspectiva del usuario, en 1-2 frases].

[Descripción de lo que cambió para el usuario en 1-2 frases].

**Para probar:**
- [Paso específico 1 que el usuario puede hacer]
- [Paso específico 2 que el usuario puede hacer]
- [Resultado esperado que debería ver]

Por favor háznoslo saber si está funcionando como esperas o si encuentras algún problema.

¡Gracias!
```

**Directrices de contenido:**

- **Lenguaje simple:** No uses términos como "OAuth", "token", "API", "validación", "condicional", etc.
- **Perspectiva del usuario:** Describe en términos de lo que el usuario experimenta
- **Pasos de prueba concretos:** Da acciones específicas que pueden realizar
- **Resultado esperado claro:** Di qué deberían ver si funciona correctamente

**Ejemplo de traducción técnico → no técnico:**

| ❌ Técnico | ✅ No técnico |
|-----------|--------------|
| "Corregimos un bug en la lógica de renovación de tokens OAuth" | "Arreglamos un problema que causaba errores de sesión" |
| "La validación de expiración usaba operador incorrecto" | "El sistema ahora mantiene tu sesión activa correctamente" |
| "Implementamos nuevo endpoint para exportación de datos" | "Ahora puedes descargar tus datos en formato Excel" |
| "Refactorizamos el componente de autenticación" | "Mejoramos la confiabilidad del inicio de sesión" |

### Paso 4: Iterar con el Usuario

**CRÍTICO: No procedas sin aprobación explícita.**

1. Presenta el borrador al usuario
2. Pregunta: "¿Este mensaje comunica claramente el cambio al stakeholder? ¿Alguna modificación necesaria?"
3. Realiza ajustes según retroalimentación
4. Repite hasta que el usuario apruebe

### Paso 5: Publicar en GitHub

**Solo después de la aprobación del usuario:**

1. Usa `mcp__github__issue_comment` para publicar el borrador como comentario en el Issue de GitHub especificado

2. Parámetros:
   - `owner`: El usuario/organización de GitHub
   - `repo`: El nombre del repositorio
   - `issue_number`: El número del issue (sin el `#`)
   - `body`: El mensaje aprobado

**Ejemplo:**
```json
{
  "owner": "odasoftmx",
  "repo": "app",
  "issue_number": 123,
  "body": "[mensaje aprobado aquí]"
}
```

### Paso 6: Confirmar

**Notificar al usuario:**
```
✅ El comentario se ha publicado en el issue de GitHub: [URL del comentario]
```

## Directrices de Tono

- **Amigable:** Usa saludos y cierre cordial
- **Simple:** Vocabulario no técnico
- **Claro:** Oraciones cortas y directas
- **Útil:** Proporciona pasos concretos de prueba
- **Profesional:** Mantén cortesía y respeto
- **Idioma:** Todo en español
- **Orientado a valor:** Enfatiza el beneficio para el usuario

## Prioridades de Contenido

### Incluir (Primario):
- Qué se arregló/agregó desde perspectiva del usuario
- Qué puede hacer ahora el usuario (o qué problema ya no verá)
- Pasos específicos para probar el cambio
- Resultado esperado de las pruebas
- Solicitud de feedback

### Incluir (Secundario):
- Contexto del negocio (si ayuda al entendimiento)
- Beneficio o impacto al flujo del usuario
- Agradecimiento por reportar el issue (si es bug report)

### Excluir:
- Detalles técnicos de implementación
- Nombres de archivos o componentes
- Jerga de desarrollo (API, endpoint, token, etc.)
- Cambios de código
- Información de arquitectura
- Métricas técnicas (tests, rendimiento)

## Ejemplos de Salida

### Ejemplo 1: Bug Fix

```markdown
Hola María,

Este issue ya está resuelto. Arreglamos el problema que causaba que tu sesión se cerrara inesperadamente cuando intentabas renovar tu acceso.

Ahora cuando tu sesión esté por expirar, el sistema la renovará automáticamente sin errores ni interrupciones.

**Para probar:**
- Inicia sesión en la aplicación
- Deja la sesión abierta por más de 1 hora
- Intenta realizar alguna acción (ej. ver un reporte)
- Deberías poder continuar trabajando sin necesidad de volver a iniciar sesión

Por favor háznoslo saber si está funcionando como esperas o si encuentras algún problema.

¡Gracias!
```

### Ejemplo 2: Nueva Funcionalidad

```markdown
Hola Carlos,

Este issue ya está resuelto. Agregamos la funcionalidad que solicitaste para exportar datos de estudiantes a Excel.

Ahora puedes descargar la lista completa de estudiantes con toda su información en un archivo Excel que puedes abrir y editar en tu computadora.

**Para probar:**
- Ve a la sección "Estudiantes" en el menú principal
- Haz clic en el botón "Exportar" en la esquina superior derecha
- Selecciona "Formato Excel"
- Descarga el archivo y ábrelo en Excel
- Deberías ver todas las columnas de información de los estudiantes correctamente organizadas

Por favor háznoslo saber si está funcionando como esperas o si encuentras algún problema.

¡Gracias!
```

### Ejemplo 3: Mejora de UX

```markdown
Hola Ana,

Este issue ya está resuelto. Mejoramos el proceso de carga de documentos para que sea más rápido y confiable.

Ahora cuando subas un documento, verás una barra de progreso clara y el documento se guardará correctamente sin necesidad de reintentar.

**Para probar:**
- Ve a la sección donde subes documentos
- Selecciona un archivo de tu computadora (prueba con uno de al menos 5MB)
- Observa la barra de progreso mientras se sube
- Confirma que aparece el mensaje de éxito cuando termina
- Verifica que el documento aparece en tu lista de documentos subidos

Por favor háznoslo saber si está funcionando como esperas o si encuentras algún problema.

¡Gracias!
```

## Errores Comunes a Evitar

❌ **Usar jerga técnica**
- "OAuth token", "API endpoint", "validación de schema", etc.

❌ **Explicar cómo se implementó**
- "Cambiamos el operador en línea 167"

❌ **Ser vago sobre las pruebas**
- "Prueba que funciona" → Dar pasos específicos

❌ **Olvidar mencionar el resultado esperado**
- Usuario no sabrá si la prueba fue exitosa

❌ **Usar inglés**
- Toda la salida debe estar en español

❌ **Tono demasiado formal o técnico**
- Debe ser amigable y accesible

❌ **Publicar sin aprobación del usuario**
- Siempre itera en el borrador primero

❌ **Asumir contexto técnico**
- Explica en términos de experiencia del usuario

## Adaptaciones Opcionales

### Si el stakeholder habla español e inglés:
Mantén español por defecto, pero puedes preguntar al usuario si prefieren el mensaje en inglés.

### Si el issue es complejo:
Divide en secciones:
```markdown
**Lo que arreglamos:**
[Explicación simple]

**Lo que esto significa para ti:**
[Impacto directo al usuario]

**Cómo probarlo:**
[Pasos específicos]
```

### Si hay múltiples stakeholders mencionados:
Usa saludo general:
```markdown
Hola equipo,

Este issue ya está resuelto. [...]
```

## Variables de Plantilla

Al usar esta plantilla, reemplaza:

- `[Nombre del Stakeholder]` - Nombre del stakeholder o "equipo" si son varios
- `[explicación simple]` - Qué se arregló/agregó en lenguaje no técnico
- `[perspectiva del usuario]` - Qué cambió para el usuario
- `[pasos de prueba]` - Acciones específicas y concretas
- `[resultado esperado]` - Qué deberían ver si funciona
- `{issue-number}` - Número del issue de GitHub (sin `#`)
- `{owner}` - Usuario u organización de GitHub
- `{repo}` - Nombre del repositorio
