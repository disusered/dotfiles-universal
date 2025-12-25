---
name: transforming-json
description: Reshapes, reformats, and transforms JSON structures using jq. Use when restructuring objects, flattening nested data, building new JSON shapes, or converting formats. For simple extraction, use parsing-json instead.
---

# Transforming JSON

Reshapes and transforms JSON data structures using jq. This skill focuses on restructuring, reformatting, and building new JSON shapes from existing data.

## Quick Start

```bash
# Reshape objects with different field names
jq '.users | map({username: .name, email: .contact.email})' data.json

# Flatten nested structure
jq '.items[].properties | {id: .id, values: [.value1, .value2]}' data.json

# Convert array to object (key-value pairs)
jq 'map({(.id): .value}) | add' data.json
```

## When to Use This Skill

- Restructuring JSON objects with different field names
- Flattening or nesting data structures
- Converting between arrays and objects
- Building new JSON shapes from existing data
- Applying complex transformations and conditionals
- **NOT for**: Simple field extraction (use parsing-json) or validation (use validating-json)

## Common Transformations

### Reshaping Objects

```bash
# Extract and rename fields
jq '{username: .name, contact: .email}' user.json

# Combine multiple fields into one
jq '{fullName: "\(.firstName) \(.lastName)", age}' person.json

# Nested restructuring
jq '.users | map({id, profile: {name, email, active}})' data.json
```

### Flattening and Nesting

```bash
# Flatten nested object
jq '{id, name, email: .contact.email, city: .address.city}' user.json

# Create nested structure
jq '{user: {id, name}, meta: {created, updated}}' record.json

# Array to nested objects
jq 'map({key: .id, data: {name, value}})' items.json
```

### Array-Object Conversions

```bash
# Array to object (using field as key)
jq 'map({(.id): .value}) | add' array.json
# Output: {"key1": "value1", "key2": "value2"}

# Object to array of key-value pairs
jq 'to_entries | map({key: .key, value: .value})' object.json

# Group array into object by field
jq 'group_by(.category) | map({key: .[0].category, items: .}) | from_entries' items.json
```

## Reference Documentation

For detailed transformations and advanced patterns:
- [TRANSFORMING.md](TRANSFORMING.md) - Core reshaping, construction, and merging operations
- [ADVANCED.md](ADVANCED.md) - Recursive descent, custom functions, string manipulation, conditionals

## Performance Notes

- Chain transformations: `jq '.items | map(select(.active)) | map({id, name})'` is more efficient than separate calls
- Use `map()` for array transformations instead of manual iteration
- Compact output (`-c`) reduces size for downstream processing
