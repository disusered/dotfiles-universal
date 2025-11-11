#!/bin/bash

# Post-tool-use tracker: Logs file changes for tracking and context
# This hook runs after Edit, Write, and MultiEdit operations
#
# SECURITY WARNING: The input JSON contains sensitive data including file contents,
# old_string, new_string, and other parameters that may contain passwords or credentials.
# NEVER log or echo the full $input variable. Only extract and log safe metadata.

set -e

# Read tool metadata from stdin
# WARNING: This contains sensitive data - do not log the raw input!
input=$(cat)

# Extract ONLY safe metadata - never log content, old_string, new_string, etc.
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.file_path // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# Only track file modification tools
if [[ ! "$tool_name" =~ ^(Edit|MultiEdit|Write)$ ]]; then
  exit 0
fi

# Skip if no file path
if [[ -z "$file_path" || "$file_path" == "null" ]]; then
  exit 0
fi

# Skip markdown files (documentation)
if [[ "$file_path" =~ \.md$ ]]; then
  exit 0
fi

# Skip files that commonly contain credentials/secrets
# This is a defense-in-depth measure to avoid logging even file paths for sensitive files
if [[ "$file_path" =~ \.(env|credentials|secret|key|pem|p12|pfx)(\.|$) ]] || \
   [[ "$file_path" =~ (password|credential|secret|api[_-]?key|token|auth)s?\.json$ ]] || \
   [[ "$file_path" =~ (^|/)\.?env($|\.) ]] || \
   [[ "$file_path" =~ (^|/)(secret|credential|password)s?($|\.|/) ]] || \
   [[ "$file_path" =~ \.ssh/ ]] || \
   [[ "$file_path" =~ \.aws/ ]] || \
   [[ "$file_path" =~ \.gnupg/ ]]; then
  exit 0
fi

# Create cache directory in deployed location
cache_dir="$HOME/.claude/.cache/tool-use"
mkdir -p "$cache_dir"

# Get timestamp
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Log the file change
log_file="$cache_dir/$session_id.log"
echo "[$timestamp] $tool_name: $file_path" >> "$log_file"

# Detect language/file type
file_ext="${file_path##*.}"
case "$file_ext" in
  ts|tsx|js|jsx)
    echo "  → TypeScript/JavaScript file modified" >> "$log_file"
    ;;
  py)
    echo "  → Python file modified" >> "$log_file"
    ;;
  go)
    echo "  → Go file modified" >> "$log_file"
    ;;
  rs)
    echo "  → Rust file modified" >> "$log_file"
    ;;
  *)
    echo "  → $file_ext file modified" >> "$log_file"
    ;;
esac

# Exit cleanly
exit 0
