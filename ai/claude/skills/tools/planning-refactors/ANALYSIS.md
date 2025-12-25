# Code Analysis and Quality Checks

Patterns for analyzing code quality and understanding codebase structure before refactoring.

## Code Quality Patterns

### Debug Statements

```bash
# Console statements (should be removed from production)
ast-grep -p 'console.log($$$)' --lang ts
ast-grep -p 'console.warn($$$)' --lang ts
ast-grep -p 'console.error($$$)' --lang ts

# Debugger statements
ast-grep -p 'debugger' --lang ts

# Print statements (Python)
ast-grep -p 'print($$$)' --lang py
```

### TODOs and FIXMEs

```bash
# TODO comments
ast-grep -p '// TODO: $$$' --lang ts
ast-grep -p '# TODO: $$$' --lang py

# FIXME comments
ast-grep -p '// FIXME: $$$' --lang ts
ast-grep -p '# FIXME: $$$' --lang py

# XXX comments
ast-grep -p '// XXX: $$$' --lang ts
```

### Empty or Suspicious Blocks

```bash
# Empty catch blocks (swallowing errors)
ast-grep -p 'catch ($E) {}' --lang ts

# Empty functions
ast-grep -p 'function $NAME($$$) {}' --lang ts

# Empty if statements
ast-grep -p 'if ($COND) {}' --lang ts
```

### Unsafe Patterns

```bash
# Any types (TypeScript)
ast-grep -p ': any' --lang ts
ast-grep -p 'as any' --lang ts

# Non-null assertions (risky)
ast-grep -p '$EXPR!' --lang ts

# Eval usage (dangerous)
ast-grep -p 'eval($$$)' --lang js

# innerHTML (XSS risk)
ast-grep -p '$ELEM.innerHTML = $$$' --lang ts
```

### Performance Anti-Patterns

```bash
# Nested loops
ast-grep -p 'for ($$$) { $$$ for ($$$) { $$$ } }' --lang ts

# Synchronous operations in loops
ast-grep -p 'for ($$$) { $$$ fs.readFileSync($$$) $$$ }' --lang ts

# Multiple awaits in loop (should use Promise.all)
ast-grep -p 'for ($$$) { $$$ await $$$; $$$ }' --lang ts

# Array index access in loop (forEach/map better)
ast-grep -p 'for ($I = 0; $$$) { $$$ $ARR[$I] $$$ }' --lang js
```

## Codebase Structure Analysis

### Finding Entry Points

```bash
# Main functions
ast-grep -p 'function main($$$)' --lang ts
ast-grep -p 'if __name__ == "__main__":' --lang py

# Exports
ast-grep -p 'export default $VALUE' --lang ts
ast-grep -p 'export function $NAME($$$)' --lang ts
ast-grep -p 'export class $NAME { $$$ }' --lang ts

# Express/API routes
ast-grep -p 'router.$METHOD("$PATH", $$$)' --lang ts
ast-grep -p 'app.$METHOD("$PATH", $$$)' --lang ts
```

### Finding React Components

```bash
# Function components
ast-grep -p 'function $COMP($PROPS) { $$$ return $$$ }' --lang tsx

# Arrow function components
ast-grep -p 'const $COMP = ($PROPS) => { $$$ return $$$ }' --lang tsx

# Class components
ast-grep -p 'class $NAME extends Component { $$$ }' --lang tsx

# HOCs (Higher-Order Components)
ast-grep -p 'function with$HOC($COMP) { $$$ }' --lang tsx
```

### Finding State Management

```bash
# Redux
ast-grep -p 'useSelector($$$)' --lang tsx
ast-grep -p 'useDispatch($$$)' --lang tsx
ast-grep -p 'createSlice({ $$$ })' --lang ts

# Context
ast-grep -p 'createContext($$$)' --lang tsx
ast-grep -p 'useContext($$$)' --lang tsx

# State hooks
ast-grep -p 'useState($$$)' --lang tsx
ast-grep -p 'useReducer($$$)' --lang tsx
```

### Finding API Integration

```bash
# HTTP clients
ast-grep -p 'axios.$METHOD($$$)' --lang ts
ast-grep -p 'fetch($URL, $$$)' --lang ts

# GraphQL
ast-grep -p 'useQuery($$$)' --lang tsx
ast-grep -p 'useMutation($$$)' --lang tsx

# WebSocket
ast-grep -p 'new WebSocket($$$)' --lang ts
```

## Dependency Analysis

### External Dependencies

```bash
# npm/node modules
ast-grep -p 'import $VAR from "$MODULE"' --lang ts | grep -v '^\.\.'

# Specific libraries
ast-grep -p 'import { $$$ } from "react"' --lang tsx
ast-grep -p 'import { $$$ } from "lodash"' --lang ts
```

### Internal Imports

```bash
# Relative imports
ast-grep -p 'import { $$$ } from "./$MODULE"' --lang ts
ast-grep -p 'import { $$$ } from "../$MODULE"' --lang ts

# Absolute imports
ast-grep -p 'import { $$$ } from "@/$MODULE"' --lang ts
```

### Circular Dependencies Risk

```bash
# Find all imports from a module
ast-grep -p 'import { $$$ } from "./moduleA"' --lang ts

# Then check if moduleA imports from those files
# (manual analysis or script)
```

## Test Coverage Analysis

### Finding Tests

```bash
# Jest/Vitest tests
ast-grep -p 'describe("$DESC", $$$)' --lang ts
ast-grep -p 'it("$DESC", $$$)' --lang ts
ast-grep -p 'test("$DESC", $$$)' --lang ts

# Python tests
ast-grep -p 'def test_$NAME($$$):' --lang py
ast-grep -p 'class Test$NAME:' --lang py
```

### Mock Usage

```bash
# Jest mocks
ast-grep -p 'jest.mock($$$)' --lang ts
ast-grep -p 'jest.spyOn($$$)' --lang ts

# Python mocks
ast-grep -p '@mock.patch($$$)' --lang py
ast-grep -p 'Mock($$$)' --lang py
```

### Coverage Gaps

```bash
# Functions without tests
# 1. Find all functions
ast-grep -p 'export function $NAME($$$) { $$$ }' --lang ts --json > functions.json

# 2. Find all test files
# 3. Compare - functions without corresponding tests are gaps
```

## Security Analysis

### Potential Vulnerabilities

```bash
# SQL injection risk
ast-grep -p 'query(`SELECT * FROM ${$TABLE}`)' --lang ts

# Command injection
ast-grep -p 'exec($CMD)' --lang ts

# Path traversal
ast-grep -p 'fs.readFile($PATH)' --lang ts  # If PATH is user input

# Unsafe regex (ReDoS)
ast-grep -p 'new RegExp($PATTERN)' --lang ts  # If PATTERN is user input
```

### Authentication/Authorization

```bash
# Find authentication checks
ast-grep -p 'if (!isAuthenticated) { $$$ }' --lang ts
ast-grep -p 'requireAuth($$$)' --lang ts

# Find authorization checks
ast-grep -p 'if (!hasPermission($$$)) { $$$ }' --lang ts
```

### Secrets in Code

```bash
# Hardcoded credentials (basic detection)
ast-grep -p 'password = "$PWD"' --lang ts
ast-grep -p 'apiKey = "$KEY"' --lang ts
ast-grep -p 'token = "$TOKEN"' --lang ts

# Better to use specialized tools like git-secrets
```

## Complexity Analysis

### Long Functions

```bash
# Find function definitions, then manually check length
ast-grep -p 'function $NAME($$$) { $$$ }' --lang ts --json | \
  jq '.[] | {function: .NAME, file, start: .range.start.line, end: .range.end.line, lines: (.range.end.line - .range.start.line)}'

# Filter for functions > 50 lines
```

### Deep Nesting

```bash
# Triple nested blocks (complexity warning)
ast-grep -p 'if ($$$) { $$$ if ($$$) { $$$ if ($$$) { $$$ } } }' --lang ts

# Nested loops
ast-grep -p 'for ($$$) { $$$ for ($$$) { $$$ for ($$$) { $$$ } } }' --lang ts
```

### Parameter Count

```bash
# Functions with many parameters (> 3-4)
ast-grep -p 'function $NAME($P1, $P2, $P3, $P4, $P5, $$$) { $$$ }' --lang ts

# Should be refactored to use options object
```

## Pre-Refactor Checklist

Before starting a refactor:

```bash
# 1. Find all affected code
ast-grep -p '<pattern>' --json > affected.json

# 2. Analyze test coverage
ast-grep -p 'describe("$NAME"' --lang ts  # Do affected modules have tests?

# 3. Check for TODOs related to this code
ast-grep -p '// TODO: $$$' affected-file.ts

# 4. Identify dependencies
ast-grep -p 'import { $$$ } from "affected-module"' --lang ts

# 5. Look for edge cases
# Read files manually, look for:
# - Error handling
# - Null checks
# - Type guards
# - Conditional logic

# 6. Document current behavior
# Before changing, understand what it does now
```

## Analysis Automation

### Generate Report

```bash
# Create analysis report
{
  echo "# Code Analysis Report"
  echo ""
  echo "## Debug Statements"
  ast-grep -p 'console.log($$$)' --lang ts | wc -l
  echo ""
  echo "## TODOs"
  ast-grep -p '// TODO: $$$' --lang ts | wc -l
  echo ""
  echo "## Empty Catch Blocks"
  ast-grep -p 'catch ($E) {}' --lang ts | wc -l
  echo ""
  echo "## Any Types"
  ast-grep -p ': any' --lang ts | wc -l
} > analysis-report.md
```

### Track Progress

```bash
# Before refactor
ast-grep -p 'oldApi.$METHOD($$$)' --lang ts | wc -l > baseline.txt

# After each phase
ast-grep -p 'oldApi.$METHOD($$$)' --lang ts | wc -l > current.txt

# Compare
diff baseline.txt current.txt
```
