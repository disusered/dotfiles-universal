#!/usr/bin/env bash
# Auto-approve safe date commands without user permission prompts

set -euo pipefail

# Read stdin (hook payload JSON)
PAYLOAD=$(cat)

# Extract the bash command from the payload
COMMAND=$(echo "$PAYLOAD" | jq -r '.parameters.command // empty')

# If no command found, don't interfere
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check if command is a date command (with or without TZ env var)
if [[ "$COMMAND" =~ ^(TZ=)?[^;]*date[[:space:]] ]]; then
  # Auto-approve date commands
  cat <<EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved safe date command"
  }
}
EOF
  exit 0
fi

# Don't interfere with other commands
exit 0
