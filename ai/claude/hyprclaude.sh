#!/usr/bin/env bash
# Hyprland claude modal launcher - uses shared library

# Source library
if [[ -f "$HOME/.local/share/hyprspace/hyprspace-lib.sh" ]]; then
  source "$HOME/.local/share/hyprspace/hyprspace-lib.sh"
else
  notify-send -u critical "hyprclaude" "Library not found: hyprspace-lib.sh"
  exit 1
fi

# Configuration
CLAUDE_BIN="/home/carlos/.local/share/mise/shims/claude"
WORKSPACE_NAME="claude"
WINDOW_CLASS="claude_modal"

# Validate dependencies
hyprspace_check_deps || exit 1

# Check if OUR workspace is visible (toggle off)
if hyprspace_is_workspace_visible "$WORKSPACE_NAME"; then
  hyprspace_toggle_off "$WORKSPACE_NAME"
  exit 0
fi

# Check if ANY OTHER special workspace is visible
# Show existing window if we have one, but don't spawn new (no context)
if hyprspace_any_special_visible >/dev/null; then
  any_existing=$(hyprctl clients -j | jq -r '.[] | select(.class == "'"$WINDOW_CLASS"'") | .address' | head -1)
  if [[ -n "$any_existing" ]]; then
    hyprspace_focus_window "$WORKSPACE_NAME" "$any_existing"
  fi
  exit 0
fi

# Get active window and context
active_info=$(hyprspace_get_active_window) || exit 1
active_class=$(echo "$active_info" | jq -r '.class')
active_pid=$(echo "$active_info" | jq -r '.pid')
active_title=$(echo "$active_info" | jq -r '.initialTitle')

# Try to get context - if we can't, only show existing windows
if ! cwd=$(hyprspace_get_kitty_context "$active_class" "$active_pid" "$active_title"); then
  # No context available (not Kitty, not modal, not Dolphin)
  # Show most recent existing window if we have one
  any_existing=$(hyprctl clients -j | jq -r '.[] | select(.class == "'"$WINDOW_CLASS"'") | .address' | head -1)
  if [[ -n "$any_existing" ]]; then
    hyprspace_focus_window "$WORKSPACE_NAME" "$any_existing"
  fi
  exit 0
fi

# Build context identifier
context_dir="${cwd%/}"
context_title="claude: $context_dir"

# Find or spawn window
existing_window=$(hyprspace_find_window "$WINDOW_CLASS" "$context_title")

if [[ -n "$existing_window" ]]; then
  # Focus existing window
  hyprspace_focus_window "$WORKSPACE_NAME" "$existing_window"
else
  # Spawn new window
  kitty --class "$WINDOW_CLASS" \
        --title "$context_title" \
        --directory "$context_dir" \
        --hold "$CLAUDE_BIN" &

  # Wait for spawn and show workspace
  if hyprspace_wait_for_window "$WINDOW_CLASS" "$context_title" "$context_dir"; then
    # Get the newly spawned window and focus it explicitly
    new_window=$(hyprspace_find_window "$WINDOW_CLASS" "$context_title")
    if [[ -n "$new_window" ]]; then
      hyprspace_focus_window "$WORKSPACE_NAME" "$new_window"
    else
      hyprspace_show_workspace "$WORKSPACE_NAME"
    fi
  fi
fi
