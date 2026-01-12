#!/usr/bin/env bash
# Hyprland AI workspace launcher - shared workspace for Claude and Gemini
# Priority: toggle off > Gemini-only > Claude matching CWD > spawn new Claude

# Source library
if [[ -f "$HOME/.local/share/hyprspace/hyprspace-lib.sh" ]]; then
  source "$HOME/.local/share/hyprspace/hyprspace-lib.sh"
else
  notify-send -u critical "hyprclaude" "Library not found: hyprspace-lib.sh"
  exit 1
fi

# Configuration
CLAUDE_BIN="/home/carlos/.local/share/mise/shims/claude"
WORKSPACE_NAME="ai"
CLAUDE_CLASS="claude_modal"
GEMINI_CLASS="chrome-gemini.google.com__-Default"

# Validate dependencies
hyprspace_check_deps || exit 1

# Check if workspace is visible (toggle off)
if hyprspace_is_workspace_visible "$WORKSPACE_NAME"; then
  hyprspace_toggle_off "$WORKSPACE_NAME"
  exit 0
fi

# Check if ANY OTHER special workspace is visible - don't interfere
if hyprspace_any_special_visible >/dev/null; then
  exit 0
fi

# Count windows in AI workspace
claude_windows=$(hyprctl clients -j | jq -r '.[] | select(.class == "'"$CLAUDE_CLASS"'") | .address')
gemini_windows=$(hyprctl clients -j | jq -r '.[] | select(.class == "'"$GEMINI_CLASS"'") | .address')

claude_count=$(echo "$claude_windows" | grep -c . || echo 0)
gemini_count=$(echo "$gemini_windows" | grep -c . || echo 0)

# If Gemini is the only window in workspace → show and focus it
if [[ "$gemini_count" -gt 0 && "$claude_count" -eq 0 ]]; then
  gemini_addr=$(echo "$gemini_windows" | head -1)
  hyprspace_focus_window "$WORKSPACE_NAME" "$gemini_addr"
  exit 0
fi

# Get active window and context
active_info=$(hyprspace_get_active_window) || exit 1
active_class=$(echo "$active_info" | jq -r '.class')
active_pid=$(echo "$active_info" | jq -r '.pid')
active_title=$(echo "$active_info" | jq -r '.initialTitle')

# Try to get context
if cwd=$(hyprspace_get_kitty_context "$active_class" "$active_pid" "$active_title"); then
  context_dir="${cwd%/}"
  context_title="claude: $context_dir"

  # Check for Claude matching this CWD
  existing_window=$(hyprspace_find_window "$CLAUDE_CLASS" "$context_title")

  if [[ -n "$existing_window" ]]; then
    # Focus existing Claude for this context
    hyprspace_focus_window "$WORKSPACE_NAME" "$existing_window"
    exit 0
  fi

  # No matching Claude - spawn new one
  kitty --class "$CLAUDE_CLASS" \
        --title "$context_title" \
        --directory "$context_dir" \
        --hold "$CLAUDE_BIN" &

  if hyprspace_wait_for_window "$CLAUDE_CLASS" "$context_title" "$context_dir"; then
    new_window=$(hyprspace_find_window "$CLAUDE_CLASS" "$context_title")
    if [[ -n "$new_window" ]]; then
      hyprspace_focus_window "$WORKSPACE_NAME" "$new_window"
    else
      hyprspace_show_workspace "$WORKSPACE_NAME"
    fi
  fi
else
  # No context available - show most recent Claude or Gemini
  any_claude=$(echo "$claude_windows" | head -1)
  any_gemini=$(echo "$gemini_windows" | head -1)

  if [[ -n "$any_claude" ]]; then
    hyprspace_focus_window "$WORKSPACE_NAME" "$any_claude"
  elif [[ -n "$any_gemini" ]]; then
    hyprspace_focus_window "$WORKSPACE_NAME" "$any_gemini"
  fi
  # If neither exists, do nothing (no context to spawn)
fi
