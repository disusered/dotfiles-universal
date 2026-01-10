#!/bin/bash
# Fast file suggestion for Claude Code using rg + fzf
# Includes Claude config files even if gitignored

QUERY=$(jq -r '.query // ""')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR" || exit 1

{
  # Main search - respects .gitignore, includes hidden files, follows symlinks
  rg --files --follow --hidden . 2>/dev/null

  # Always include Claude files even if gitignored
  [ -d .claude ] && rg --files --follow --hidden --no-ignore-vcs .claude 2>/dev/null
  [ -f CLAUDE.md ] && echo "CLAUDE.md"
} | sort -u | fzf --filter "$QUERY" | head -15
