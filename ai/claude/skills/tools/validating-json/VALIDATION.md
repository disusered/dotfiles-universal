# JSON Validation and Debugging

Common errors, solutions, and debugging techniques for working with JSON.

## Validation Basics

### Quick Validation

```bash
# Fast validation (no output if valid)
jq empty data.json
echo $?  # 0 = valid, 1 = invalid

# Validate and show content
jq '.' data.json

# Validate and suppress output
jq '.' data.json > /dev/null 2>&1 && echo "Valid" || echo "Invalid"
```

### Batch Validation

```bash
# Validate multiple files
for file in *.json; do
    if jq empty "$file" 2>/dev/null; then
        echo "✓ $file: valid"
    else
        echo "✗ $file: invalid"
    fi
done

# Or use the provided script
ai/claude/skills/tools/validating-json/scripts/validate-batch.sh *.json
```

## Common Errors and Solutions

### Error: "parse error: Expected separator between values"

**Cause**: Missing comma between array elements or object properties

```bash
# Invalid
{"a": 1 "b": 2}
[1 2 3]

# Valid
{"a": 1, "b": 2}
[1, 2, 3]
```

**Solution**: Add commas between elements

### Error: "parse error: Invalid numeric literal"

**Cause**: Invalid number format (leading zeros, trailing comma, etc.)

```bash
# Invalid
{"value": 01234}  # Leading zero
{"value": 123,}   # Trailing comma

# Valid
{"value": 1234}
{"value": 123}
```

**Solution**: Remove leading zeros, trailing commas

### Error: "parse error: Expected value before"

**Cause**: Trailing comma in array or object

```bash
# Invalid
{"a": 1, "b": 2,}
[1, 2, 3,]

# Valid
{"a": 1, "b": 2}
[1, 2, 3]
```

**Solution**: Remove trailing comma

### Error: "parse error: Unfinished string"

**Cause**: Unclosed string, unescaped quote

```bash
# Invalid
{"name": "Alice}
{"path": "C:\folder"}

# Valid
{"name": "Alice"}
{"path": "C:\\folder"}
```

**Solution**: Close strings, escape backslashes and quotes

### Error: "Cannot index string with string"

**Cause**: Trying to access object key on a string value

```bash
# Check structure first
jq '.' data.json

# If root is an object
jq '.field' data.json

# If root is an array
jq '.[0].field' data.json

# If nested
jq '.data.items[0].field' data.json
```

**Solution**: Verify JSON structure matches your query

### Error: "Cannot iterate over null"

**Cause**: Trying to iterate over null or missing field

```bash
# Fails if .items is null
jq '.items[]' data.json

# Solutions:
jq '.items[]?' data.json           # Optional iteration
jq '.items // [] | .[]' data.json  # Default to empty array
jq 'if .items then .items[] else empty end' data.json  # Conditional
```

## Debugging Techniques

### Inspect Structure

```bash
# View entire structure formatted
jq '.' data.json

# See all top-level keys
jq 'keys' data.json

# Check type of value
jq '.field | type' data.json

# See nested structure
jq '.data | keys' data.json
```

### Trace Execution

```bash
# Show intermediate values
jq --debug-trace '.items[] | select(.active) | .name' data.json

# Trace with custom message
jq '.items[] | debug | select(.active)' data.json

# Show specific values during processing
jq '.items[] | {debug: ., result: select(.active)}' data.json
```

### Identify Invalid Parts

```bash
# Check each field individually
jq '.field1' data.json  # If this works...
jq '.field2' data.json  # ...but this fails, field2 is the problem

# Check array elements one by one
jq '.[0]' data.json
jq '.[1]' data.json

# Test path exists
jq 'has("field")' data.json
```

## Formatting for Readability

### Pretty-Print Options

```bash
# Standard pretty-print
jq '.' data.json

# Compact (remove whitespace)
jq -c '.' data.json

# Sort keys alphabetically
jq -S '.' data.json

# Tab indentation (default is 2 spaces)
jq --tab '.' data.json

# Custom indentation via compact + python
jq -c '.' data.json | python -m json.tool --indent 4
```

### Readable Output for Logs

```bash
# Extract and format as table-like output
jq -r '.items[] | "\(.id)\t\(.name)\t\(.status)"' data.json

# Custom formatting
jq -r '.users[] | "User: \(.name) <\(.email)>"' data.json

# CSV format
jq -r '.items[] | [.id, .name, .price] | @csv' data.json
```

## Validation Best Practices

### Pre-Process Validation

```bash
# Always validate before processing
if jq empty data.json 2>/dev/null; then
    # Process the file
    jq '.items[] | select(.active)' data.json
else
    echo "Error: Invalid JSON in data.json"
    exit 1
fi
```

### Pipeline Validation

```bash
# Validate at each step
curl -s api.example.com/data | \
    tee original.json | \
    jq empty && \
    jq '.results[]' original.json
```

### Preserve Original

```bash
# Create formatted copy, keep original
jq '.' ugly.json > pretty.json

# Validate before overwriting
jq '.' data.json > temp.json && mv temp.json data.json
```

## Performance Considerations

### Fast Validation

```bash
# Fastest: jq empty (no output)
jq empty large.json

# Slower: jq '.' (outputs entire file)
jq '.' large.json > /dev/null

# Slowest: debug mode
jq --debug-trace '.' large.json > /dev/null
```

### Large File Handling

```bash
# Stream processing for very large files
jq --stream 'select(length == 2)' huge.json

# Validate without loading entire file
head -c 1000000 large.json | jq empty
```

### Memory Usage

```bash
# Compact output uses less memory
jq -c '.' large.json > compact.json

# Process in chunks
jq -c '.items[]' large.json | while read -r item; do
    echo "$item" | jq '.'
done
```

## Troubleshooting Workflow

When encountering JSON errors:

1. **Validate**: Run `jq empty file.json` to confirm error
2. **Locate**: Use error message line/column numbers
3. **Inspect**: View the problematic section with `jq '.'`
4. **Fix**: Correct the syntax error
5. **Re-validate**: Confirm fix with `jq empty file.json`
6. **Test**: Run your actual query

Common fixes:
- Add missing commas
- Remove trailing commas
- Escape backslashes and quotes in strings
- Remove leading zeros from numbers
- Close unclosed brackets/braces
