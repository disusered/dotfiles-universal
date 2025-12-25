#!/bin/bash
# Validates multiple JSON files with structured feedback
# Returns 0 if all files are valid, 1 if any file is invalid

exit_code=0

# Check if any files provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file1.json> [file2.json ...]"
    exit 1
fi

for file in "$@"; do
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "✗ $file: file not found"
        exit_code=1
        continue
    fi

    # Validate JSON
    if jq empty "$file" 2>/dev/null; then
        echo "✓ $file: valid"
    else
        echo "✗ $file: invalid"
        # Show error details indented
        jq empty "$file" 2>&1 | sed 's/^/  /'
        exit_code=1
    fi
done

exit $exit_code
