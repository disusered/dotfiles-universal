#!/usr/bin/env bash
set -euo pipefail

git_root=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --git-root) git_root="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$git_root" ]] && exit 0

dir="${XDG_CACHE_HOME:-$HOME/.cache}/nvim-servers"
[[ -d "$dir" ]] || exit 0

shopt -s nullglob
files=("$dir"/*.json)
(( ${#files[@]} == 0 )) && exit 0

while IFS=$'\t' read -r sock pid; do
  [[ -S "$sock" ]] || continue
  kill -0 "$pid" 2>/dev/null || continue
  printf '%s\n' "$sock"
  exit 0
done < <(jq -sr --arg gr "$git_root" '
  map(select(.git_root == $gr))
  | sort_by(.started_at)
  | .[] | "\(.socket)\t\(.pid)"
' "${files[@]}")
