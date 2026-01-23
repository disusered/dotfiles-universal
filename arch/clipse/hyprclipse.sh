#!/usr/bin/env bash
# Hyprland clipse launcher - uses shared library

# Source library
if [[ -f "$HOME/.local/share/hyprspace/hyprspace-lib.sh" ]]; then
  source "$HOME/.local/share/hyprspace/hyprspace-lib.sh"
else
  notify-send -u critical "hyprclipse" "Library not found: hyprspace-lib.sh"
  exit 1
fi

# Configuration
WORKSPACE_NAME="clipboard"
WINDOW_CLASS="clipse_scratch"
WINDOW_TITLE="clipse"

# Validate dependencies
hyprspace_check_deps || exit 1

# Check if OUR workspace is visible (toggle off)
if hyprspace_is_workspace_visible "$WORKSPACE_NAME"; then
  hyprspace_toggle_off "$WORKSPACE_NAME"
  exit 0
fi

# Check if ANY OTHER special workspace is visible - don't interfere
if hyprspace_any_special_visible >/dev/null; then
  exit 0
fi

# Check for existing clipse window (global - no context needed)
existing=$(hyprctl clients -j | jq -r '.[] | select(.class == "'"$WINDOW_CLASS"'") | .address' | head -1)

if [[ -n "$existing" ]]; then
  # Focus existing window
  hyprspace_focus_window "$WORKSPACE_NAME" "$existing"
else
  # Spawn new clipse window
  kitty --class "$WINDOW_CLASS" --title "$WINDOW_TITLE" clipse &

  # Wait for spawn and show workspace
  if hyprspace_wait_for_window "$WINDOW_CLASS" "$WINDOW_TITLE" "clipse"; then
    new_window=$(hyprctl clients -j | jq -r '.[] | select(.class == "'"$WINDOW_CLASS"'") | .address' | head -1)
    if [[ -n "$new_window" ]]; then
      hyprspace_focus_window "$WORKSPACE_NAME" "$new_window"
    else
      hyprspace_show_workspace "$WORKSPACE_NAME"
    fi
  fi
fi
