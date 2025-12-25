# Pattern Syntax and Construction

Wildcard syntax, pattern construction, and language-specific examples for ast-grep searches.

## Contents

- [Wildcard Types](#wildcard-types)
- [Pattern Construction](#pattern-construction)
- [Matching Specificity](#matching-specificity)
- [Advanced Pattern Features](#advanced-pattern-features)
- [Pattern Debugging](#pattern-debugging)
- [Pattern Recipes](#pattern-recipes)
- [Language-Specific Examples](#language-specific-examples)
  - [JavaScript/TypeScript](#javascripttypescript)
  - [Python](#python)
  - [Go](#go)
  - [Rust](#rust)

## Wildcard Types

### Single Node: $VAR

Matches exactly one AST node (expression, identifier, statement, etc.)

```bash
# Match function calls with one argument
ast-grep -p 'useState($INIT)'
# Matches: useState(0), useState(null), useState([])
# Does NOT match: useState(), useState(0, setter)

# Match assignments
ast-grep -p 'const $VAR = $VALUE'
# Matches: const x = 5, const user = getUser()
```

### Variable Arguments: $$$VARS

Matches zero or more nodes in sequence (like spread operator)

```bash
# Match function with any number of parameters
ast-grep -p 'function $NAME($$$PARAMS) { $$$ }'
# Matches: function foo(), function bar(a, b, c)

# Match array with any number of elements
ast-grep -p '[$$$ITEMS]'
# Matches: [], [1], [1, 2, 3]

# Match import with any named imports
ast-grep -p 'import { $$$NAMES } from "$MODULE"'
# Matches: import { a } from "lib", import { a, b, c } from "lib"
```

### Anonymous Wildcard: $$$

Matches any node sequence when you don't need to reference it

```bash
# Match if statement with any condition and body
ast-grep -p 'if ($$$) { $$$ }'
# Matches any if statement

# Match try-catch with any content
ast-grep -p 'try { $$$ } catch ($E) { $$$ }'
# Matches any try-catch block
```

## Pattern Construction

### Building Patterns

Start with the code structure you want to find, then replace parts with wildcards:

```bash
# Original code:
const user = fetchUser(123)

# Pattern (replace specific values):
const $VAR = fetchUser($ID)

# Pattern (match any function):
const $VAR = $FUNC($ARG)

# Pattern (match any assignment):
const $VAR = $VALUE
```

### Naming Wildcards

Use descriptive names to make patterns clear:

```bash
# Good: Clear what each wildcard represents
ast-grep -p 'function $FUNCTION_NAME($$$PARAMETERS) { $$$ }'

# Less clear: Generic names
ast-grep -p 'function $A($$$B) { $$$ }'

# Names can help when using --json output
ast-grep -p 'const [$STATE, $SETTER] = useState($INIT)' --json
# Output includes: STATE="count", SETTER="setCount", INIT="0"
```

## Matching Specificity

### Narrow vs Broad Patterns

```bash
# Very specific (fewer matches)
ast-grep -p 'const [$STATE, $SETTER] = useState(0)'
# Matches only useState initialized with 0

# More general
ast-grep -p 'const [$STATE, $SETTER] = useState($INIT)'
# Matches any useState with destructured assignment

# Very broad
ast-grep -p 'useState($$$)'
# Matches all useState calls
```

### Balancing Precision

Too narrow:
```bash
# Misses variations
ast-grep -p 'function handleClick() { $$$ }'
# Misses: function handleClick(event) { ... }
```

Too broad:
```bash
# Too many matches
ast-grep -p '$FUNC($$$)'
# Matches EVERY function call in codebase
```

Just right:
```bash
# Specific enough to be useful
ast-grep -p 'handle$EVENT($$$)'
# Matches: handleClick, handleSubmit, handleChange
```

## Advanced Pattern Features

### Nested Patterns

```bash
# Match nested function calls
ast-grep -p '$OUTER($INNER($$$))'
# Matches: map(parseInt(...)), filter(isValid(...))

# Match nested object access
ast-grep -p '$OBJ.$PROP.$METHOD($$$)'
# Matches: user.profile.getName(), api.client.request(...)
```

### Optional Elements

```bash
# Function with optional return type (TypeScript)
ast-grep -p 'function $NAME($$$): $$$' --lang ts
# Matches both with and without explicit return type

# Class with optional extends
ast-grep -p 'class $NAME { $$$ }' --lang ts
# Matches: class Foo {}, class Bar extends Baz {}
```

### Combining Multiple Wildcards

```bash
# Multiple named wildcards
ast-grep -p 'const $VAR1 = $VAR2.$METHOD($ARG)'
# Captures each part separately

# Mix of named and anonymous
ast-grep -p 'if ($CONDITION) { return $VALUE; $$$ }'
# Named: CONDITION, VALUE; Anonymous: rest of block
```

## Pattern Debugging

### Test Pattern Incrementally

```bash
# Start broad
ast-grep -p 'function $NAME($$$) { $$$ }'

# Add specificity
ast-grep -p 'async function $NAME($$$) { $$$ }'

# Narrow further
ast-grep -p 'async function $NAME($$$): Promise<$TYPE> { $$$ }'
```

### Verify Pattern Match

```bash
# Use --heading to see file context
ast-grep -p '<pattern>' --heading

# Use --context to see surrounding code
ast-grep -p '<pattern>' --context 3

# Use --json to see what was captured
ast-grep -p 'const $VAR = $VALUE' --json | jq '.[] | {var: .VAR, value: .VALUE}'
```

### Common Pattern Mistakes

```bash
# WRONG: Missing $$$ for function body
ast-grep -p 'function $NAME($$$PARAMS)'
# Doesn't match - function body required

# CORRECT: Include body wildcard
ast-grep -p 'function $NAME($$$PARAMS) { $$$ }'

# WRONG: Too specific with whitespace
ast-grep -p 'if ($COND)  {  $$$  }'  # Extra spaces
# May not match all formatting

# CORRECT: Use standard formatting
ast-grep -p 'if ($COND) { $$$ }'
```

## Pattern Recipes

### Find Function Definitions

```bash
# Any function
ast-grep -p 'function $NAME($$$) { $$$ }'

# Arrow functions
ast-grep -p 'const $NAME = ($$$) => { $$$ }'
ast-grep -p 'const $NAME = ($$$) => $EXPR'  # Expression body

# Methods
ast-grep -p '$METHOD($$$) { $$$ }'  # In class or object
```

### Find Variable Usage

```bash
# Declaration
ast-grep -p 'const $VAR = $VALUE'
ast-grep -p 'let $VAR = $VALUE'

# Reassignment
ast-grep -p '$VAR = $VALUE'

# In destructuring
ast-grep -p 'const { $$$, $VAR, $$$ } = $OBJ'
```

### Find API Calls

```bash
# Specific API
ast-grep -p 'fetch($URL, $$$)'

# Any method on object
ast-grep -p '$API.$METHOD($$$)'

# Chained calls
ast-grep -p '$OBJ.$METHOD1($$$).$METHOD2($$$)'
```

### Find Error Handling

```bash
# Try-catch
ast-grep -p 'try { $$$ } catch ($E) { $$$ }'

# Error checking
ast-grep -p 'if ($ERR) { $$$ }'

# Throw statements
ast-grep -p 'throw new $ERROR($$$)'
```

## Language-Specific Examples

### JavaScript/TypeScript

```bash
# React hooks
ast-grep -p 'use$HOOK($$$)' --lang tsx
ast-grep -p 'const [$STATE, $SETTER] = useState($INIT)' --lang tsx

# Async functions
ast-grep -p 'async function $NAME($$$) { $$$ }' --lang ts

# Arrow functions
ast-grep -p 'const $NAME = ($$$) => { $$$ }' --lang js

# Imports
ast-grep -p 'import { $$$NAMES } from "$MODULE"' --lang ts

# Fetch/axios
ast-grep -p 'await fetch($URL, $$$)' --lang ts
ast-grep -p 'axios.$METHOD($$$)' --lang ts

# TypeScript interfaces
ast-grep -p 'interface $NAME { $$$ }' --lang ts
```

### Python

```bash
# Function definitions
ast-grep -p 'def $FUNC($$$):' --lang py
ast-grep -p 'async def $FUNC($$$):' --lang py

# Class definitions
ast-grep -p 'class $NAME($BASE):' --lang py

# Decorators
ast-grep -p '@$DECORATOR' --lang py

# List comprehension
ast-grep -p '[$EXPR for $VAR in $ITER]' --lang py

# Imports
ast-grep -p 'from $MODULE import $$$' --lang py

# Error handling
ast-grep -p 'try: $$$ except $E: $$$' --lang py
```

### Go

```bash
# Function definitions
ast-grep -p 'func $NAME($$$) $$$' --lang go

# Struct definitions
ast-grep -p 'type $NAME struct { $$$ }' --lang go

# Interface definitions
ast-grep -p 'type $NAME interface { $$$ }' --lang go

# Error handling
ast-grep -p 'if err != nil { $$$ }' --lang go

# Goroutines
ast-grep -p 'go $FUNC($$$)' --lang go

# Methods
ast-grep -p 'func ($RECV $TYPE) $METHOD($$$) $$$' --lang go
```

### Rust

```bash
# Function definitions
ast-grep -p 'fn $NAME($$$) -> $TYPE { $$$ }' --lang rust
ast-grep -p 'pub fn $NAME($$$) { $$$ }' --lang rust

# Struct definitions
ast-grep -p 'struct $NAME { $$$ }' --lang rust

# Impl blocks
ast-grep -p 'impl $TRAIT for $TYPE { $$$ }' --lang rust

# Match statements
ast-grep -p 'match $EXPR { $$$ }' --lang rust

# Macros
ast-grep -p '$MACRO!($$$)' --lang rust

# Error handling
ast-grep -p '$EXPR?' --lang rust
ast-grep -p '$EXPR.unwrap()' --lang rust
```
