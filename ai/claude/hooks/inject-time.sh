#!/usr/bin/env bash
# Inject current time into every prompt so Claude doesn't need to run date commands

set -euo pipefail

# Pass through stdin
cat

# Add current time to context
echo ""
echo "Current time (America/Tijuana): $(TZ='America/Tijuana' date '+%Y-%m-%d %H:%M')"
