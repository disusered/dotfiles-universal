#!/bin/bash
set -e

cd "$CLAUDE_PROJECT_DIR/ai/claude/hooks"
cat | npx tsx skill-activation-prompt.ts
