---
name: parsing-json
description: Extracts fields and filters data from JSON files, API responses, and command output using jq. Use when reading JSON files, extracting specific fields, filtering arrays, or parsing structured data. For reshaping JSON, use transforming-json. For validation, use validating-json.
---

# Parsing JSON

Extracts and filters JSON data using jq. This skill covers the most common JSON operations: reading files, extracting fields, and filtering arrays.

## Quick Start

```bash
# Extract field from JSON file
jq '.fieldname' file.json

# Extract from API response
curl -s api.example.com/users | jq '.users[].email'

# Filter array by condition
jq '.[] | select(.status == "active")' data.json
```

## When to Use This Skill

- Reading JSON files and extracting specific fields
- Parsing API responses and command output
- Filtering arrays by conditions
- Navigating nested JSON structures
- **NOT for**: Reshaping JSON (use transforming-json) or validation (use validating-json)

## Common Patterns

### Field Access

```bash
# Access top-level field
jq '.name' file.json

# Access nested field
jq '.user.email' file.json

# Access array element
jq '.[0]' array.json
jq '.[1:3]' array.json  # Slice
```

### Array Operations

```bash
# Iterate array (each element on new line)
jq '.[]' array.json

# Extract field from each element
jq '.[].name' users.json

# Collect results into array
jq '[.[].name]' users.json

# Get array length
jq 'length' array.json
```

### Filtering

```bash
# Filter by condition
jq '.[] | select(.age > 18)' users.json

# Multiple conditions
jq '.[] | select(.age > 18 and .active == true)' users.json

# Check if key exists
jq 'has("fieldname")' file.json

# Default value for null
jq '.field // "default"' file.json
```

### Useful Options

```bash
# Raw output (no quotes on strings)
jq -r '.name' file.json

# Compact output (no pretty-print)
jq -c '.' file.json

# Read from stdin
echo '{"key":"value"}' | jq '.key'
```

## Reference Documentation

For detailed information, see:
- [BASICS.md](BASICS.md) - Core concepts, field access, arrays, objects
- [FILTERING.md](FILTERING.md) - Advanced filtering with select, map, and conditions
- [REFERENCE.md](REFERENCE.md) - Complete use cases and integration patterns

## Integration

Combines with other tools:

```bash
# With ast-grep for code analysis
ast-grep -p 'function $NAME($$$)' --json | jq '.[].file' -r

# With curl for APIs
curl -s api.example.com/data | jq '.results[] | {id, name}'

# With grep for pre-filtering
grep "error" log.json | jq '.timestamp, .message'
```

## Performance Tips

- Use `-c` for compact output with large files
- Filter early in the pipeline: `jq '.items[] | select(.active)'` instead of `jq '.items | map(select(.active))'`
- Use `-r` when piping to other tools (avoids quote escaping)
- Pipe directly instead of writing intermediate files
