#!/usr/bin/env bash
set -euo pipefail

payload="$(cat || true)"
if [[ -z "$payload" ]] || ! command -v jq >/dev/null 2>&1; then
  printf 'agy\n'
  exit 0
fi

workspace="$(printf '%s' "$payload" | jq -r '.cwd // empty | split("/") | last // empty' 2>/dev/null || true)"
state="$(printf '%s' "$payload" | jq -r '.agent_state // .state // empty' 2>/dev/null || true)"

if [[ -n "$workspace" && -n "$state" ]]; then
  printf 'agy · %s · %s\n' "$workspace" "$state"
elif [[ -n "$workspace" ]]; then
  printf 'agy · %s\n' "$workspace"
else
  printf 'agy\n'
fi
