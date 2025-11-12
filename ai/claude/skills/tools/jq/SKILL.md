---
name: jq
description: Use jq for JSON parsing, filtering, and transformation. Prefer this over grep when working with JSON data. Automatically loaded for JSON analysis tasks.
allowed-tools: Bash
---

# jq Reference

JSON processor for parsing, filtering, and transforming JSON data.

## Why jq?

- **JSON-native**: Understands JSON structure, not just text patterns
- **Powerful filtering**: Extract specific fields without manual parsing
- **Transformation**: Reshape and reformat JSON data
- **Streaming**: Process large JSON files efficiently
- **Precise queries**: Navigate nested structures with ease

## Basic Syntax

```bash
jq [OPTIONS] '<filter>' [file]
```

## Core Concepts

### Identity and Basic Filters

```bash
# Pretty-print JSON
echo '{"name":"test","value":123}' | jq '.'

# Access field
echo '{"name":"test","value":123}' | jq '.name'
# Output: "test"

# Access nested field
echo '{"user":{"name":"Alice","age":30}}' | jq '.user.name'
# Output: "Alice"

# Access array element
echo '["a","b","c"]' | jq '.[1]'
# Output: "b"

# Array slice
echo '[1,2,3,4,5]' | jq '.[1:3]'
# Output: [2,3]
```

### Array Operations

```bash
# Iterate over array (outputs each element on separate line)
echo '[{"name":"Alice"},{"name":"Bob"}]' | jq '.[]'

# Extract field from each array element
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq '.[].name'
# Output: "Alice" "Bob"

# Collect results into array
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq '[.[].name]'
# Output: ["Alice","Bob"]

# Get array length
echo '[1,2,3,4,5]' | jq 'length'
# Output: 5

# Map over array
echo '[1,2,3]' | jq 'map(. * 2)'
# Output: [2,4,6]

# Select/filter array elements
echo '[1,2,3,4,5]' | jq 'map(select(. > 2))'
# Output: [3,4,5]
```

### Object Operations

```bash
# Get all keys
echo '{"name":"Alice","age":30,"city":"NYC"}' | jq 'keys'
# Output: ["age","city","name"]

# Get all values
echo '{"name":"Alice","age":30}' | jq 'values'

# Construct new object
echo '{"name":"Alice","age":30}' | jq '{name: .name, older: (.age + 1)}'
# Output: {"name":"Alice","older":31}

# Merge objects
echo '{"a":1}' | jq '. + {"b":2}'
# Output: {"a":1,"b":2}
```

### Filtering and Selection

```bash
# Select objects matching condition
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq '.[] | select(.age > 26)'
# Output: {"name":"Alice","age":30}

# Check if key exists
echo '{"name":"Alice"}' | jq 'has("name")'
# Output: true

# Filter with multiple conditions
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq '.[] | select(.age > 20 and .name == "Alice")'

# Check for null/empty
echo '{"a":null,"b":"value"}' | jq '.a // "default"'
# Output: "default"
```

### Useful Options

```bash
# Compact output (no pretty-print)
jq -c '.'

# Raw output (no quotes for strings)
jq -r '.name'

# Sort keys
jq -S '.'

# Read raw input (not JSON)
jq -R '.'

# Slurp (read entire input as array)
jq -s '.'

# Exit status based on output
jq -e '.exists' # exits 1 if null/false
```

## Common Use Cases

### Parsing API Responses

```bash
# Extract specific field from API response
curl -s api.example.com/users | jq '.users[].email'

# Get first result
curl -s api.example.com/search | jq '.results[0]'

# Count results
curl -s api.example.com/items | jq '.items | length'

# Extract and format
curl -s api.example.com/users | jq '.users[] | "\(.name): \(.email)"'
```

### Working with Package Files

```bash
# Get npm package version
jq -r '.version' package.json

# List all dependencies
jq -r '.dependencies | keys[]' package.json

# Get specific dependency version
jq -r '.dependencies.react' package.json

# List all scripts
jq '.scripts' package.json
```

### Filtering Large JSON Files

```bash
# Find specific items
jq '.[] | select(.status == "active")' data.json

# Extract fields from matches
jq '.[] | select(.price > 100) | {name, price}' products.json

# Group and count
jq 'group_by(.category) | map({category: .[0].category, count: length})' items.json
```

### Transforming Data

```bash
# Reshape objects
jq '.users | map({username: .name, email: .contact.email})' data.json

# Flatten nested structure
jq '.items[].properties | {id: .id, values: [.value1, .value2]}' data.json

# Convert array to object
jq 'map({(.id): .value}) | add' data.json
```

### Combining with Other Tools

```bash
# Use with grep for pre-filtering
grep "error" log.json | jq '.timestamp, .message'

# Use with ast-grep
ast-grep -p 'async function $NAME($$$)' --json | jq '.[] | .file' -r

# Pipe to other tools
jq -r '.urls[]' data.json | xargs -I {} curl -O {}

# Process multiple files
jq -s 'add' file1.json file2.json file3.json
```

## Advanced Patterns

### Recursive Descent

```bash
# Find all values for a key anywhere in structure
jq '.. | .email? // empty' data.json

# Recursively find objects with specific key
jq '.. | objects | select(has("error"))' data.json
```

### Custom Functions

```bash
# Define and use functions
jq 'def double: . * 2; map(double)' numbers.json

# Recursive functions
jq 'def factorial: if . <= 1 then 1 else . * ((. - 1) | factorial) end; factorial'
```

### Conditional Logic

```bash
# If-then-else
jq 'if .age >= 18 then "adult" else "minor" end'

# Complex conditionals
jq 'if .status == "active" then .price * 0.9 elif .status == "pending" then .price else .price * 1.1 end'
```

### String Manipulation

```bash
# String interpolation
jq '"Hello, \(.name)!"'

# Split and join
jq 'split(",")' # split string
jq 'join(", ")' # join array

# Test/match regex
jq 'test("^[A-Z]")' # returns boolean
jq 'match("([0-9]+)")' # returns match object

# Replace
jq 'gsub("old"; "new")'
```

## Debugging

```bash
# Debug output (shows intermediate values)
jq --debug-trace '.'

# Pretty-print for readability
jq '.' ugly.json > pretty.json

# Validate JSON
jq empty data.json # exits 0 if valid, 1 if invalid
```

## Performance Tips

- Use `-c` for compact output when processing large files
- Use `--stream` for very large JSON files that don't fit in memory
- Filter early: `jq '.items[] | select(.active)' is better than `jq '.items | map(select(.active))'`
- Use `-r` when you need raw strings (avoids quote escaping)
- Pipe directly instead of writing intermediate files

## Integration with Claude Code

When analyzing JSON data:

1. **Use jq instead of grep** for JSON structure queries
2. **Combine with other tools**: ast-grep outputs JSON, pipe to jq
3. **Parse configuration files**: package.json, tsconfig.json, etc.
4. **Process API responses**: Format and extract relevant data
5. **Debug JSON logs**: Filter and format log files

### Recommended Workflow

```bash
# 1. Validate JSON first
jq empty data.json

# 2. Explore structure
jq 'keys' data.json

# 3. Extract what you need
jq '.items[] | select(.status == "active") | {id, name, price}' data.json

# 4. Format for readability
jq -r '.items[] | "\(.id): \(.name) - $\(.price)"' data.json
```

## Common Errors and Solutions

```bash
# Error: "Cannot index string with string"
# Solution: Check if you're accessing the right level
jq '.data.items' instead of jq '.items'

# Error: "Cannot iterate over null"
# Solution: Add null check
jq '.items[]?' or jq '.items // [] | .[]'

# Error: "Invalid numeric literal"
# Solution: Quote numbers in filters
jq '.["123"]' instead of jq '.123'
```

## Getting Help

```bash
# Show manual
man jq

# Show version
jq --version

# Online playground: https://jqplay.org
```

## Installation

If jq is not available, install it:

```bash
# Arch Linux
sudo pacman -S jq

# Fedora/RHEL
sudo dnf install jq

# macOS
brew install jq

# Windows (Scoop)
scoop install jq

# Build from source
git clone https://github.com/jqlang/jq.git
cd jq
autoreconf -i
./configure
make
sudo make install
```

## jq vs grep/ripgrep

| Feature | grep/ripgrep | jq |
|---------|--------------|-----|
| JSON awareness | ❌ Text only | ✅ Native JSON |
| Structural queries | ❌ | ✅ |
| Field extraction | ⚠️ Regex only | ✅ Built-in |
| Nested data | ❌ Very difficult | ✅ Easy |
| Data transformation | ❌ | ✅ Powerful |
| Pretty-printing | ❌ | ✅ Built-in |
| Type safety | ❌ | ✅ JSON types |

**Rule of thumb**: Use jq for JSON data, grep for text content, ast-grep for code structure.

## Quick Reference Card

```bash
# Access
.foo              # field
.foo.bar          # nested field
.[0]              # array index
.[]               # array elements

# Filter
select(.age>18)   # filter condition
map(. * 2)        # transform each
unique            # unique values
sort              # sort array
reverse           # reverse array
group_by(.key)    # group items

# Combine
+                 # merge/concat
|                 # pipe
,                 # multiple outputs
//                # alternative operator

# Output
-c                # compact
-r                # raw strings
-S                # sort keys
-e                # exit code
-s                # slurp (array)
```
