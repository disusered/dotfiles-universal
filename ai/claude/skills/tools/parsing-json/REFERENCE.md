# JSON Parsing Reference

Complete reference for common JSON parsing use cases.

## Contents

- [Parsing API Responses](#parsing-api-responses)
- [Working with Package Files](#working-with-package-files)
- [Filtering Large JSON Files](#filtering-large-json-files)
- [Combining with Other Tools](#combining-with-other-tools)
- [Common Errors and Solutions](#common-errors-and-solutions)
- [Performance Tips](#performance-tips)

## Parsing API Responses

### Extract Specific Fields

```bash
# Extract single field from all items
curl -s api.example.com/users | jq '.users[].email'

# Extract multiple fields
curl -s api.example.com/users | jq '.users[] | {name, email}'

# Get first result
curl -s api.example.com/search | jq '.results[0]'

# Get last N results
curl -s api.example.com/items | jq '.items[-5:]'
```

### Count and Aggregate

```bash
# Count results
curl -s api.example.com/items | jq '.items | length'

# Sum numeric values
curl -s api.example.com/sales | jq '[.sales[].amount] | add'

# Average
curl -s api.example.com/metrics | jq '[.values[]] | add / length'
```

### Format Output

```bash
# Extract and format as string
curl -s api.example.com/users | jq '.users[] | "\(.name): \(.email)"'

# Format as CSV
curl -s api.example.com/users | jq -r '.users[] | [.id, .name, .email] | @csv'

# Format as TSV
curl -s api.example.com/data | jq -r '.items[] | [.field1, .field2] | @tsv'
```

## Working with Package Files

### npm package.json

```bash
# Get package version
jq -r '.version' package.json

# List all dependencies
jq -r '.dependencies | keys[]' package.json

# Get specific dependency version
jq -r '.dependencies.react' package.json

# List all scripts
jq '.scripts' package.json

# Check if dependency exists
jq 'has("dependencies") and .dependencies | has("react")' package.json
```

### Composer/Cargo/Go Modules

```bash
# composer.json (PHP)
jq '.require' composer.json

# Cargo.toml (after converting to JSON)
jq '.dependencies' Cargo.json

# go.mod (after parsing to JSON)
jq '.require[] | select(.indirect | not)' go-deps.json
```

## Filtering Large JSON Files

### Find Specific Items

```bash
# Find by exact match
jq '.[] | select(.status == "active")' data.json

# Find by partial match (contains)
jq '.[] | select(.name | contains("test"))' data.json

# Find by regex
jq '.[] | select(.email | test("@example\\.com$"))' users.json

# Find by numeric range
jq '.[] | select(.price > 100 and .price < 500)' products.json
```

### Extract Fields from Matches

```bash
# Get specific fields from filtered results
jq '.[] | select(.price > 100) | {name, price}' products.json

# Extract single field from matches
jq '[.[] | select(.status == "active") | .id]' items.json

# Count matches
jq '[.[] | select(.category == "electronics")] | length' products.json
```

### Group and Aggregate

```bash
# Group by field and count
jq 'group_by(.category) | map({category: .[0].category, count: length})' items.json

# Group by field and sum
jq 'group_by(.category) | map({category: .[0].category, total: map(.amount) | add})' transactions.json

# Group by multiple fields
jq 'group_by([.category, .status]) | map({key: .[0] | {category, status}, count: length})' items.json
```

## Combining with Other Tools

### With grep for Pre-filtering

```bash
# Filter lines before parsing (faster for large files)
grep "error" log.json | jq '.timestamp, .message'

# Find specific pattern then parse
grep "user_id.*12345" events.json | jq '.event_type'
```

### With ast-grep for Code Analysis

```bash
# Parse ast-grep JSON output
ast-grep -p 'async function $NAME($$$)' --json | jq '.[] | .file' -r

# Extract unique files
ast-grep -p 'console.log($$$)' --json | jq -r '[.[].file] | unique[]'

# Group by file
ast-grep -p 'useState($$$)' --json | jq 'group_by(.file) | map({file: .[0].file, count: length})'
```

### Pipe to Other Tools

```bash
# Download URLs from JSON
jq -r '.urls[]' data.json | xargs -I {} curl -O {}

# Process files listed in JSON
jq -r '.files[]' manifest.json | xargs -I {} md5sum {}

# Feed to another command
jq -r '.servers[] | .host' config.json | xargs -I {} ping -c 1 {}
```

### Process Multiple Files

```bash
# Merge multiple JSON files into array
jq -s '.' file1.json file2.json file3.json

# Combine objects
jq -s 'add' file1.json file2.json

# Process each file separately
jq '.items[] | .id' file1.json file2.json file3.json
```

## Common Errors and Solutions

### "Cannot index string with string"

**Problem**: Accessing wrong nesting level

```bash
# Wrong: trying to access .items on string
jq '.items' file.json  # fails if root is string

# Solution: check structure first
jq '.' file.json  # see actual structure
jq '.data.items' file.json  # access correct level
```

### "Cannot iterate over null"

**Problem**: Trying to iterate null/missing array

```bash
# Wrong: .items might be null
jq '.items[]' file.json

# Solution: use optional iteration or default
jq '.items[]?' file.json
jq '.items // [] | .[]' file.json
```

### "Invalid numeric literal"

**Problem**: Numeric keys need quotes

```bash
# Wrong
jq '.123' file.json

# Correct
jq '.["123"]' file.json
```

### "Unexpected token"

**Problem**: Invalid JSON input

```bash
# Solution: validate JSON first
jq empty file.json  # exits 0 if valid, 1 if invalid

# Then parse
jq '.' file.json
```

## Performance Tips

### Filter Early

```bash
# Good: filter before processing
jq '.items[] | select(.active) | .name' data.json

# Slow: process all then filter
jq '.items | map(.name) | map(select(contains("active")))' data.json
```

### Use Compact Output for Large Files

```bash
# Faster for large datasets
jq -c '.items[] | select(.status == "active")' huge-file.json

# Saves space and parsing time
jq -c '.' input.json > output.json
```

### Stream Processing

```bash
# For very large files that don't fit in memory
jq --stream 'select(.[0][0] == "items")' huge-file.json
```

### Avoid Intermediate Files

```bash
# Good: pipe directly
curl -s api.example.com/data | jq '.results[] | .id' | sort

# Slow: write intermediate files
curl -s api.example.com/data > temp.json
jq '.results[] | .id' temp.json > ids.txt
sort ids.txt
```

### Use Raw Output

```bash
# Faster when piping to other tools (no quote escaping)
jq -r '.items[].name' data.json | grep "test"

# Slower: keeps quotes
jq '.items[].name' data.json | grep "test"
```

## Quick Reference Card

```bash
# Access
.foo              # field
.foo.bar          # nested field
.[0]              # array index
.[]               # array elements
.[-1]             # last element

# Filter
select(.age>18)   # filter condition
map(. * 2)        # transform each
unique            # unique values
sort              # sort array
group_by(.key)    # group items

# Output
-c                # compact
-r                # raw strings (no quotes)
-s                # slurp (read all as array)
-e                # exit code based on result

# Operators
|                 # pipe
//                # alternative (default)
,                 # multiple outputs
```
