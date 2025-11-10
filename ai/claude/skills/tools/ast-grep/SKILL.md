---
name: ast-grep
description: Use ast-grep for structural code search and analysis. Automatically loaded for planning agents and code inspection tasks. Prefer this over naive grep for code lookups.
allowed-tools: Bash
---

# ast-grep Reference

Structural code search and refactoring tool that understands syntax.

## Why ast-grep?

- **Syntax-aware**: Understands code structure, not just text patterns
- **Language support**: JavaScript, TypeScript, Python, Go, Rust, Java, and more
- **Precise matching**: Avoids false positives from comments or strings
- **Pattern matching**: Use `$VAR` wildcards to match any expression

## Basic Syntax

```bash
ast-grep [OPTIONS] <PATTERN>
```

## Core Commands

### Search for patterns

```bash
# Basic pattern search
ast-grep --pattern '<pattern>' [path]

# Search with language specification
ast-grep --pattern '<pattern>' --lang <language> [path]

# Options:
#   --pattern, -p    Pattern to search for
#   --lang, -l       Language (js, ts, py, go, rust, java, etc.)
#   --json          Output as JSON for parsing
#   --heading       Show file headings in output (default)
#   --no-heading    Suppress file headings
#   --context N     Show N lines of context around matches

# Examples:
ast-grep --pattern 'console.log($MSG)' --lang ts
ast-grep --pattern 'function $FUNC($$$PARAMS) { $$$ }' --lang js
ast-grep --pattern 'class $CLASS:' --lang py
```

### Pattern syntax

```bash
# Wildcards:
#   $VAR          Matches a single AST node (expression, identifier, etc.)
#   $$$VARS       Matches zero or more nodes (varargs)
#   $$$           Anonymous wildcard (matches any node sequence)

# Examples:
ast-grep -p 'useState($INIT)'                    # Find useState calls
ast-grep -p 'if ($COND) { $$$ }'                 # Find if statements
ast-grep -p 'function $NAME($$$ARGS) { $$$ }'    # Find functions
ast-grep -p 'const $VAR = $VALUE'                # Find const declarations
ast-grep -p 'import { $$$NAMES } from "$MODULE"' # Find imports
```

### File filtering

```bash
# Search specific file types
ast-grep --pattern '<pattern>' --lang ts 'src/**/*.ts'

# Use globs (similar to ripgrep)
ast-grep --pattern '<pattern>' 'src/**/*.{ts,tsx}'

# Examples:
ast-grep -p 'useEffect($$$)' 'src/components/**/*.tsx'
ast-grep -p 'def $FUNC($$$):' 'tests/**/*.py'
```

### Advanced usage

```bash
# Output as JSON for parsing
ast-grep --pattern '<pattern>' --json

# Combine with other tools
ast-grep -p 'async function $NAME($$$)' --json | jq '.[] | .file'

# Multiple patterns (requires config file)
ast-grep scan --rule <rule-file.yml>
```

## Common Patterns

### JavaScript/TypeScript

```bash
# Find all React hooks
ast-grep -p 'use$HOOK($$$)' --lang tsx

# Find async functions
ast-grep -p 'async function $NAME($$$PARAMS) { $$$ }' --lang ts

# Find class components
ast-grep -p 'class $NAME extends Component { $$$ }' --lang tsx

# Find useState with specific initial value
ast-grep -p 'const [$STATE, $SETTER] = useState($INIT)' --lang ts

# Find props destructuring
ast-grep -p 'function $COMP({ $$$PROPS })' --lang tsx

# Find API calls
ast-grep -p 'fetch($URL, $$$)' --lang ts
ast-grep -p 'axios.$METHOD($$$)' --lang ts

# Find error handling
ast-grep -p 'try { $$$ } catch ($E) { $$$ }' --lang ts

# Find imports
ast-grep -p 'import $DEFAULT from "$MODULE"' --lang ts
ast-grep -p 'import { $$$NAMED } from "$MODULE"' --lang ts
```

### Python

```bash
# Find class definitions
ast-grep -p 'class $NAME:' --lang py
ast-grep -p 'class $NAME($BASE):' --lang py

# Find function definitions
ast-grep -p 'def $FUNC($$$):' --lang py
ast-grep -p 'async def $FUNC($$$):' --lang py

# Find decorators
ast-grep -p '@$DECORATOR' --lang py

# Find exception handling
ast-grep -p 'try: $$$ except $E: $$$' --lang py

# Find comprehensions
ast-grep -p '[$EXPR for $VAR in $ITER]' --lang py
```

### Go

```bash
# Find function definitions
ast-grep -p 'func $NAME($$$) $$$' --lang go

# Find struct definitions
ast-grep -p 'type $NAME struct { $$$ }' --lang go

# Find interface definitions
ast-grep -p 'type $NAME interface { $$$ }' --lang go

# Find error handling
ast-grep -p 'if err != nil { $$$ }' --lang go

# Find goroutines
ast-grep -p 'go $FUNC($$$)' --lang go
```

### Rust

```bash
# Find function definitions
ast-grep -p 'fn $NAME($$$) { $$$ }' --lang rust

# Find struct definitions
ast-grep -p 'struct $NAME { $$$ }' --lang rust

# Find impl blocks
ast-grep -p 'impl $TRAIT for $TYPE { $$$ }' --lang rust

# Find match statements
ast-grep -p 'match $EXPR { $$$ }' --lang rust
```

## Integration with Planning

When used by planning agents, ast-grep provides:

1. **Accurate symbol location**: Find exact definitions, not just mentions
2. **Structural context**: Understand how code is organized
3. **Cross-reference analysis**: Find all usages of a symbol
4. **Type-aware search**: Match based on syntax, not strings

### Recommended workflow

1. Use ast-grep to find symbol definitions
2. Use ast-grep to find all references
3. Use Read tool to examine context
4. Use Edit tool to make changes

### Example planning workflow

```bash
# 1. Find the function definition
ast-grep -p 'function handleAuth($$$)' --lang ts 'src/**/*.ts'

# 2. Find all calls to the function
ast-grep -p 'handleAuth($$$)' --lang ts 'src/**/*.ts'

# 3. Read the file to understand context
# (Use Read tool)

# 4. Make targeted changes
# (Use Edit tool)
```

## Performance Tips

- Always specify `--lang` for better accuracy
- Use file globs to limit search scope
- Use `--no-heading` when parsing output programmatically
- Combine with `--json` for structured output

## Common Use Cases

### Finding specific patterns before refactoring

```bash
# Find all places where a deprecated API is used
ast-grep -p 'oldApi.$METHOD($$$)' --lang ts

# Find all class components (for migration to hooks)
ast-grep -p 'class $NAME extends Component' --lang tsx

# Find all direct state mutations (should use setState)
ast-grep -p 'this.state.$PROP = $VALUE' --lang ts
```

### Code review and quality checks

```bash
# Find console.log statements
ast-grep -p 'console.log($$$)' --lang ts

# Find TODO comments in code
ast-grep -p '// TODO: $$$' --lang ts

# Find empty catch blocks
ast-grep -p 'catch ($E) {}' --lang ts
```

### Understanding codebase structure

```bash
# Find all exported functions
ast-grep -p 'export function $NAME($$$)' --lang ts

# Find all React components
ast-grep -p 'function $NAME($PROPS) { $$$ return $$$ }' --lang tsx

# Find all API routes
ast-grep -p 'router.$METHOD("$PATH", $$$)' --lang ts
```

## Getting Help

```bash
# Show help
ast-grep --help

# Show language support
ast-grep --list-languages

# Show version
ast-grep --version
```

## Installation

If ast-grep is not available, install it:

```bash
# Using cargo (Rust)
cargo install ast-grep

# Using npm
npm install -g @ast-grep/cli

# Using homebrew (macOS)
brew install ast-grep
```

## Advantages over grep/ripgrep

| Feature | grep/ripgrep | ast-grep |
|---------|-------------|----------|
| Syntax awareness | ❌ Text only | ✅ AST-based |
| Structural matching | ❌ | ✅ |
| Language support | ❌ | ✅ 20+ languages |
| Wildcards | ✅ Regex | ✅ AST nodes |
| False positives | ⚠️ High (comments, strings) | ✅ Low |
| Performance | ✅ Very fast | ✅ Fast |

**Rule of thumb**: Use ast-grep for code structure, grep for text content.
