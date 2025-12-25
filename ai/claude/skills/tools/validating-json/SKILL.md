---
name: validating-json
description: Validates, pretty-prints, and debugs JSON data using jq. Use when checking JSON validity, formatting for readability, or troubleshooting malformed JSON. For working with valid JSON, use parsing-json instead.
---

# Validating JSON

Validates, formats, and debugs JSON data using jq. This skill focuses on checking JSON validity, identifying errors, and improving readability.

## Quick Start

```bash
# Validate JSON file
jq empty data.json  # exits 0 if valid, 1 if invalid

# Pretty-print JSON for readability
jq '.' ugly.json > pretty.json

# Validate and show errors
jq '.' data.json 2>&1 || echo "Invalid JSON"
```

## When to Use This Skill

- Checking if JSON is valid before processing
- Formatting JSON for better readability
- Debugging malformed JSON files
- Batch validation of multiple JSON files
- Identifying specific JSON parsing errors
- **NOT for**: Parsing valid JSON (use parsing-json) or transforming JSON (use transforming-json)

## Validation Workflow

Copy this checklist when validating multiple files:

```
Validation Progress:
- [ ] Step 1: Run batch validator on all JSON files
- [ ] Step 2: Review errors from validation output
- [ ] Step 3: Fix malformed JSON files
- [ ] Step 4: Re-run validator
- [ ] Step 5: Proceed only when all files valid
```

### Step 1: Run Batch Validator

Use the validation script for multiple files:

```bash
# Validate all JSON files in current directory
ai/claude/skills/tools/validating-json/scripts/validate-batch.sh *.json

# Validate specific files
ai/claude/skills/tools/validating-json/scripts/validate-batch.sh file1.json file2.json

# Validate all JSON in directory tree
find . -name "*.json" -exec ai/claude/skills/tools/validating-json/scripts/validate-batch.sh {} +
```

### Step 2-4: Fix and Re-validate

The script shows which files failed. Fix each one and re-run the validator until all pass.

### Step 5: Proceed

Only when all validations pass should you proceed with parsing or transformation.

## Common Validation Operations

### Single File Validation

```bash
# Check if valid (exit code 0 = valid, 1 = invalid)
jq empty data.json

# Validate and show errors
jq '.' data.json 2>&1

# Validate with specific error details
jq empty data.json 2>&1 | head -n 1
```

### Pretty-Printing

```bash
# Format JSON for readability
jq '.' compact.json > readable.json

# Pretty-print to stdout
jq '.' data.json

# Sort keys alphabetically
jq -S '.' data.json

# Compact formatting (opposite of pretty)
jq -c '.' pretty.json > compact.json
```

### Debug Mode

```bash
# Show intermediate values during processing
jq --debug-trace '.items[] | select(.active)' data.json

# Trace execution with timestamps
jq --debug-trace '.' data.json 2>&1 | grep "TRACE"
```

## Reference Documentation

For detailed error handling and solutions:
- [VALIDATION.md](VALIDATION.md) - Common errors, solutions, and debugging techniques

## Performance Notes

- Validate before processing to avoid wasted computation
- Use `jq empty` for fast validation (doesn't output anything)
- Batch validation with the provided script is faster than individual checks
- Pretty-printing large files can be slow; use `-c` if you only need validation
