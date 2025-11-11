#!/usr/bin/env bash
# UserPromptSubmit hook: Inject current time into every prompt
# Follows pattern from https://code.claude.com/docs/en/hooks.md

set -euo pipefail

# Read JSON input from stdin (required by hook spec)
# We don't need to process it since we're only injecting context
read -r -d '' input_json || true

# Inject current time as additional context
# Hook output on stdout becomes context Claude receives
echo "Current time (America/Tijuana): $(TZ='America/Tijuana' date '+%Y-%m-%d %H:%M')"

# Exit 0 to allow prompt to proceed normally
exit 0
