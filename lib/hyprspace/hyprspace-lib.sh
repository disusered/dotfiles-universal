#!/usr/bin/env bash
# Shared library for Hyprland special workspace launchers
# Provides unified functions for context detection, window management, and workspace toggling

# Validate dependencies
hyprspace_check_deps() {
  local missing=()
  command -v hyprctl >/dev/null || missing+=("hyprctl")
  command -v jq >/dev/null || missing+=("jq")
  command -v kitty >/dev/null || missing+=("kitty")

  if [[ ${#missing[@]} -gt 0 ]]; then
    notify-send -u critical "hyprspace" "Missing: ${missing[*]}"
    return 1
  fi
  return 0
}

# Get active window with error handling
hyprspace_get_active_window() {
  local result
  if ! result=$(hyprctl activewindow -j 2>/dev/null); then
    notify-send -u critical "hyprspace" "Failed to query Hyprland"
    return 1
  fi
  echo "$result"
}

# Extract context from Kitty window (including modal windows which are Kitty terminals)
# Args: $1=active_class, $2=active_pid, $3=active_initial_title (optional)
# Returns: cwd path on stdout, exit code 0 on success, 1 if no context found
# NOTE: Does NOT fall back to $HOME - caller must handle failure
hyprspace_get_kitty_context() {
  local active_class="$1"
  local active_pid="$2"
  local active_title="$3"
  local cwd=""

  # For regular Kitty windows, query the socket
  if [[ "$active_class" == "kitty" ]]; then
    local kitty_state
    kitty_state=$(kitty @ --to "unix:@mykitty-$active_pid" ls 2>/dev/null) || \
                 kitty_state=$(kitty @ --to "unix:@mykitty" ls 2>/dev/null) || \
                 kitty_state=""

    if [[ -n "$kitty_state" ]]; then
      cwd=$(echo "$kitty_state" | jq -r '.[] | .tabs[] | .windows[] | select(.is_focused) | .cwd' | head -1)
      [[ "$cwd" == "null" ]] && cwd=""
    fi
  # For modal windows, parse the initialTitle (format: "app: /path/to/dir")
  elif [[ "$active_class" == *_modal && -n "$active_title" ]]; then
    # Extract path after ": " (e.g., "claude: /home/carlos/.dotfiles" -> "/home/carlos/.dotfiles")
    local parsed_path="${active_title#*: }"
    if [[ -d "$parsed_path" ]]; then
      cwd="$parsed_path"
    fi
  # For Dolphin file manager, check for org.kde.dolphin class
  elif [[ "$active_class" == "org.kde.dolphin" ]]; then
    # Dolphin's title often contains the current path
    # Format varies: "path — Dolphin" or just "path"
    local parsed_path="${active_title%% —*}"
    if [[ -d "$parsed_path" ]]; then
      cwd="$parsed_path"
    fi
  fi

  if [[ -n "$cwd" ]]; then
    echo "$cwd"
    return 0
  else
    return 1
  fi
}

# Check if workspace visible on focused monitor
# Args: $1=workspace_name
hyprspace_is_workspace_visible() {
  local workspace_name="$1"
  local focused_special
  focused_special=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name')
  [[ "$focused_special" == "special:$workspace_name" ]]
}

# Check if ANY special workspace is visible on focused monitor
# Returns: 0 if a special workspace is visible, 1 otherwise
# Outputs: the special workspace name (without "special:" prefix) if visible
hyprspace_any_special_visible() {
  local focused_special
  focused_special=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name')
  if [[ "$focused_special" == special:* ]]; then
    echo "${focused_special#special:}"
    return 0
  fi
  return 1
}

# Toggle workspace off
# Args: $1=workspace_name
hyprspace_toggle_off() {
  local workspace_name="$1"
  hyprctl dispatch togglespecialworkspace "$workspace_name"
}

# Find existing window by class and title
# Args: $1=window_class, $2=initial_title
# Returns: window address or empty
hyprspace_find_window() {
  local window_class="$1"
  local initial_title="$2"
  hyprctl clients -j | jq -r --arg title "$initial_title" \
    '.[] | select(.class == "'"$window_class"'" and .initialTitle == $title) | .address'
}

# Show workspace and focus specific window
# Args: $1=workspace_name, $2=window_address
hyprspace_focus_window() {
  local workspace_name="$1"
  local window_addr="$2"

  # Show workspace first
  if ! hyprctl dispatch togglespecialworkspace "$workspace_name" >/dev/null 2>&1; then
    notify-send -u normal "hyprspace" "Failed to show workspace: $workspace_name"
    return 1
  fi

  # Then focus specific window
  if ! hyprctl dispatch focuswindow "address:$window_addr" >/dev/null 2>&1; then
    notify-send -u low "hyprspace" "Failed to focus window"
    return 1
  fi
}

# Wait for window to appear with lockfile and timeout
# Args: $1=window_class, $2=initial_title, $3=context_id (for locking)
# Returns: 0 on success, 1 on timeout
hyprspace_wait_for_window() {
  local window_class="$1"
  local initial_title="$2"
  local context_id="$3"
  local lock_file="/tmp/hyprspace-${context_id//\//_}.lock"

  # Acquire lock (non-blocking)
  exec 200>"$lock_file"
  if ! flock -n 200; then
    notify-send -u low "hyprspace" "Already spawning window for this context"
    return 1
  fi
  trap "rm -f $lock_file" EXIT

  # Wait for window to appear
  for _ in {1..20}; do
    sleep 0.1
    if hyprctl clients -j | jq -e --arg title "$initial_title" \
       '.[] | select(.class == "'"$window_class"'" and .initialTitle == $title)' >/dev/null 2>&1; then
      return 0
    fi
  done

  notify-send -u normal "hyprspace" "Window spawn timeout: $initial_title"
  return 1
}

# Show workspace after successful spawn
# Args: $1=workspace_name
hyprspace_show_workspace() {
  local workspace_name="$1"
  if ! hyprctl dispatch togglespecialworkspace "$workspace_name" >/dev/null 2>&1; then
    notify-send -u normal "hyprspace" "Failed to show workspace: $workspace_name"
    return 1
  fi
}
