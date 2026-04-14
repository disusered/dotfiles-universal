#!/usr/bin/env bash
set -euo pipefail

ctx="${1:-$PWD}"
cd "$ctx" 2>/dev/null || true

if sock="$("$HOME/.local/bin/resolve-nvim-parent" --git-root "$ctx" 2>/dev/null)" && [[ -n "$sock" ]]; then
  export NVIM="$sock"
fi

export HYPRSPACE_MODAL=lazygit

exec lazygit
