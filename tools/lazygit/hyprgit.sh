#!/usr/bin/env bash
# Hyprland lazygit modal launcher
# Queries focused kitty window cwd, finds git root, spawns lazygit

# Check if lazygit modal already exists (toggle off)
lazygit_pid=$(hyprctl clients -j | jq -r '.[] | select(.class == "lazygit_modal") | .pid')
if [[ -n "$lazygit_pid" ]]; then
  kill "$lazygit_pid" 2>/dev/null
  exit 0
fi

# Verify focused window is kitty
active_info=$(hyprctl activewindow -j)
active_class=$(echo "$active_info" | jq -r '.class')
active_pid=$(echo "$active_info" | jq -r '.pid')

if [[ "$active_class" != "kitty" ]]; then
  notify-send -u normal "Lazygit" "No Kitty window focused (got: $active_class)"
  exit 1
fi

# Query kitty for focused window's cwd and check for neovim
# Kitty appends the PID to the socket name when multiple instances are running
kitty_state=$(kitty @ --to "unix:@mykitty-$active_pid" ls 2>/dev/null)

# Fallback to generic socket if PID-specific fails
if [[ -z "$kitty_state" ]]; then
    kitty_state=$(kitty @ --to unix:@mykitty ls 2>/dev/null)
fi

cwd=$(echo "$kitty_state" | jq -r '
  .[] | .tabs[] | .windows[] | select(.is_focused) | .cwd
' | head -1)


# Check if focused window is running neovim and get its PID
nvim_pid=$(echo "$kitty_state" | jq -r '
  .[] | .tabs[] | .windows[] | select(.is_focused) |
  .foreground_processes[] | select(.cmdline[0] == "nvim") | .pid
' | head -1)

# Fallback: warn if no kitty context
if [[ -z "$cwd" || "$cwd" == "null" ]]; then
  notify-send -u normal "Lazygit" "No Kitty window focused"
  exit 1
fi

# Find git root from cwd
git_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)

if [[ -z "$git_root" ]]; then
  notify-send -u normal "Lazygit" "Not a git repository: $cwd"
  exit 1
fi

# Spawn lazygit in floating kitty window
#
# Build NVIM env if neovim is running in the focused window
nvim_env=""
if [[ -n "$nvim_pid" && "$nvim_pid" != "null" ]]; then
  nvim_socket="/run/user/$(id -u)/nvim.${nvim_pid}.0"
  if [[ -S "$nvim_socket" ]]; then
    nvim_env="--env NVIM=$nvim_socket"
  fi
fi

kitty --class lazygit_modal --directory "$git_root" $nvim_env lazygit
