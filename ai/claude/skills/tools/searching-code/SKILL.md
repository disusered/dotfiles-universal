---
name: searching-code
description: Finds code patterns using structural syntax matching with ast-grep. Use when searching for function definitions, class structures, API calls, or specific code patterns where grep would match false positives from comments or strings. For planning refactors, use planning-refactors instead.
---

# Searching Code

Finds code patterns using structural syntax matching with ast-grep. This skill focuses on locating specific code structures accurately without false positives from comments or strings.

## Quick Start

```bash
# Find React hooks
ast-grep -p 'use$HOOK($$$)' --lang tsx

# Find async functions
ast-grep -p 'async function $NAME($$$)' --lang ts

# Find class definitions
ast-grep -p 'class $NAME:' --lang py
```

## When to Use This Skill

- Finding function or class definitions by structure
- Locating specific API calls or patterns
- Searching for language constructs (hooks, decorators, error handling)
- Finding code that grep would miss or over-match
- Extracting structured data from code with `--json`
- **NOT for**: Planning refactors or migrations (use planning-refactors instead)

## Pattern Syntax

### Wildcards

```bash
# $VAR - Matches a single AST node
ast-grep -p 'useState($INIT)'

# $$$VARS - Matches zero or more nodes (varargs)
ast-grep -p 'function $NAME($$$ARGS) { $$$ }'

# $$$ - Anonymous wildcard (any node sequence)
ast-grep -p 'if ($COND) { $$$ }'
```

### Common Patterns

```bash
# Variable declarations
ast-grep -p 'const $VAR = $VALUE' --lang js

# Function calls
ast-grep -p '$FUNC($$$)' --lang ts

# Imports
ast-grep -p 'import { $$$NAMES } from "$MODULE"' --lang ts

# Try-catch blocks
ast-grep -p 'try { $$$ } catch ($E) { $$$ }' --lang ts
```

## Basic Usage

### Search Commands

```bash
# Search with pattern
ast-grep --pattern '<pattern>' --lang <language>

# Search specific files
ast-grep -p 'useEffect($$$)' 'src/**/*.tsx'

# Output as JSON for parsing
ast-grep -p 'async function $NAME($$$)' --json | jq '.[] | .file' -r

# Show context around matches
ast-grep -p 'console.log($$$)' --context 3
```

### File Filtering

```bash
# Glob patterns
ast-grep -p 'def $FUNC($$$):' 'tests/**/*.py'

# Multiple file types
ast-grep -p '<pattern>' 'src/**/*.{ts,tsx}'

# Specific directories
ast-grep -p '<pattern>' --lang rust 'src/lib/**'
```

## Reference Documentation

For detailed patterns and language-specific examples:
- [PATTERNS.md](PATTERNS.md) - Wildcard syntax, pattern construction, language-specific examples

## Integration

```bash
# With jq for processing results
ast-grep -p 'function $NAME($$$)' --json | jq '.[] | .file' -r

# Unique files with matches
ast-grep -p 'console.log($$$)' --json | jq -r '[.[].file] | unique[]'

# Count matches per file
ast-grep -p 'useState($$$)' --json | jq 'group_by(.file) | map({file: .[0].file, count: length})'
```

## Performance Notes

- ast-grep is syntax-aware and avoids false positives from comments/strings
- `--json` output is structured for easy parsing with jq
- File globs reduce search scope and improve speed
- More specific patterns match faster than broad wildcards
