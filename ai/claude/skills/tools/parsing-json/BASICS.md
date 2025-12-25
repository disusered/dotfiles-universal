# JSON Parsing Basics

Core concepts for extracting data from JSON using jq.

## Identity and Basic Filters

### Pretty-print JSON

```bash
echo '{"name":"test","value":123}' | jq '.'
```

Output:
```json
{
  "name": "test",
  "value": 123
}
```

### Access Fields

```bash
# Access single field
echo '{"name":"test","value":123}' | jq '.name'
# Output: "test"

# Access nested field
echo '{"user":{"name":"Alice","age":30}}' | jq '.user.name'
# Output: "Alice"
```

### Access Array Elements

```bash
# Single element
echo '["a","b","c"]' | jq '.[1]'
# Output: "b"

# Array slice
echo '[1,2,3,4,5]' | jq '.[1:3]'
# Output: [2,3]

# Last element
echo '[1,2,3,4,5]' | jq '.[-1]'
# Output: 5
```

## Array Operations

### Iterate Over Arrays

```bash
# Output each element on separate line
echo '[{"name":"Alice"},{"name":"Bob"}]' | jq '.[]'
# Output:
# {"name":"Alice"}
# {"name":"Bob"}

# Extract field from each element
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq '.[].name'
# Output:
# "Alice"
# "Bob"
```

### Collect Results

```bash
# Collect extracted values into array
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq '[.[].name]'
# Output: ["Alice","Bob"]
```

### Array Length

```bash
echo '[1,2,3,4,5]' | jq 'length'
# Output: 5
```

### Map Over Arrays

```bash
# Transform each element
echo '[1,2,3]' | jq 'map(. * 2)'
# Output: [2,4,6]

# Map to object
echo '[1,2,3]' | jq 'map({value: .})'
# Output: [{"value":1},{"value":2},{"value":3}]
```

## Object Operations

### Get All Keys

```bash
echo '{"name":"Alice","age":30,"city":"NYC"}' | jq 'keys'
# Output: ["age","city","name"]  # Sorted alphabetically
```

### Get All Values

```bash
echo '{"name":"Alice","age":30}' | jq 'values'
# Output:
# "Alice"
# 30
```

### Construct New Objects

```bash
# Build object from fields
echo '{"name":"Alice","age":30}' | jq '{name: .name, older: (.age + 1)}'
# Output: {"name":"Alice","older":31}

# Select specific fields
echo '{"name":"Alice","age":30,"city":"NYC"}' | jq '{name, age}'
# Output: {"name":"Alice","age":30}
```

### Merge Objects

```bash
echo '{"a":1}' | jq '. + {"b":2}'
# Output: {"a":1,"b":2}

# Later values override
echo '{"a":1,"b":2}' | jq '. + {"b":3}'
# Output: {"a":1,"b":3}
```

## Common Options

```bash
# Compact output (no pretty-print)
jq -c '.' file.json

# Raw output (no quotes for strings)
jq -r '.name' file.json

# Sort keys
jq -S '.' file.json

# Read raw input (not JSON)
jq -R '.' file.txt

# Slurp (read entire input as array)
jq -s '.' file1.json file2.json

# Exit status based on output
jq -e '.exists' file.json  # exits 1 if null/false
```

## Null Handling

```bash
# Optional field access (no error if missing)
jq '.field?' file.json

# Default value for null
jq '.field // "default"' file.json

# Check for null
jq '.field | if . == null then "missing" else . end' file.json
```
