# Hyprspace Library

Shared library for Hyprland special workspace launchers. Provides unified functions for context detection, window management, and workspace toggling.

## Purpose

Consolidates common logic from `hyprclaude.sh` and `hyprgit.sh` to eliminate code duplication and ensure consistent behavior across all special workspace launchers.

## API Reference

### Dependency Validation

#### `hyprspace_check_deps()`
Validates that required dependencies (hyprctl, jq, kitty) are available.

**Returns:** 0 on success, 1 if any dependency is missing
**Side effects:** Sends notification if dependencies are missing

**Example:**
```bash
hyprspace_check_deps || exit 1
```

### Context Detection

#### `hyprspace_get_active_window()`
Gets the currently active window information from Hyprland.

**Returns:** JSON string with window info, or exits with error
**Side effects:** Sends notification on failure

**Example:**
```bash
active_info=$(hyprspace_get_active_window) || exit 1
active_class=$(echo "$active_info" | jq -r '.class')
```

#### `hyprspace_get_kitty_context(active_class, active_pid)`
Extracts the working directory from the focused Kitty pane.

**Args:**
- `$1`: Active window class
- `$2`: Active window PID

**Returns:** Working directory path (defaults to $HOME if detection fails)
**Side effects:** Sends low-priority notification if Kitty context cannot be retrieved

**Example:**
```bash
cwd=$(hyprspace_get_kitty_context "$active_class" "$active_pid")
```

### Workspace Management

#### `hyprspace_is_workspace_visible(workspace_name)`
Checks if the special workspace is visible on the focused monitor.

**Args:**
- `$1`: Workspace name (without "special:" prefix)

**Returns:** 0 if visible, 1 if not

**Example:**
```bash
if hyprspace_is_workspace_visible "claude"; then
  echo "Claude workspace is visible"
fi
```

#### `hyprspace_toggle_off(workspace_name)`
Hides the special workspace.

**Args:**
- `$1`: Workspace name (without "special:" prefix)

**Example:**
```bash
hyprspace_toggle_off "claude"
```

#### `hyprspace_show_workspace(workspace_name)`
Shows the special workspace.

**Args:**
- `$1`: Workspace name (without "special:" prefix)

**Returns:** 0 on success, 1 on failure
**Side effects:** Sends notification on failure

**Example:**
```bash
hyprspace_show_workspace "claude" || exit 1
```

### Window Management

#### `hyprspace_find_window(window_class, initial_title)`
Finds an existing window by class and initialTitle.

**Args:**
- `$1`: Window class (e.g., "claude_modal")
- `$2`: Initial title to match

**Returns:** Window address or empty string if not found

**Example:**
```bash
existing=$(hyprspace_find_window "claude_modal" "claude: /home/carlos/projects")
if [[ -n "$existing" ]]; then
  echo "Found existing window: $existing"
fi
```

#### `hyprspace_focus_window(workspace_name, window_address)`
Shows the workspace and focuses a specific window.

**Args:**
- `$1`: Workspace name (without "special:" prefix)
- `$2`: Window address to focus

**Returns:** 0 on success, 1 on failure
**Side effects:** Sends notifications on failure

**Example:**
```bash
hyprspace_focus_window "claude" "$window_addr"
```

#### `hyprspace_wait_for_window(window_class, initial_title, context_id)`
Waits for a window to appear after spawning, with lockfile protection against concurrent invocations.

**Args:**
- `$1`: Window class
- `$2`: Initial title to wait for
- `$3`: Context ID (used for lockfile naming)

**Returns:** 0 if window appears within 2 seconds, 1 on timeout or lock conflict
**Side effects:**
- Creates lockfile at `/tmp/hyprspace-{context_id}.lock`
- Sends notification on timeout or lock conflict
- Cleans up lockfile on EXIT

**Example:**
```bash
if hyprspace_wait_for_window "claude_modal" "$context_title" "$context_dir"; then
  echo "Window spawned successfully"
fi
```

## Usage Pattern

Typical launcher script structure:

```bash
#!/usr/bin/env bash
# Source library
source "$HOME/.local/share/hyprspace/hyprspace-lib.sh" || exit 1

# Configuration
APP_BIN="myapp"
WORKSPACE_NAME="myapp"
WINDOW_CLASS="myapp_modal"

# Validate dependencies
hyprspace_check_deps || exit 1

# Get context
active_info=$(hyprspace_get_active_window) || exit 1
active_class=$(echo "$active_info" | jq -r '.class')
active_pid=$(echo "$active_info" | jq -r '.pid')
cwd=$(hyprspace_get_kitty_context "$active_class" "$active_pid")
context_title="myapp: ${cwd%/}"

# Toggle off if visible
if hyprspace_is_workspace_visible "$WORKSPACE_NAME"; then
  hyprspace_toggle_off "$WORKSPACE_NAME"
  exit 0
fi

# Find or spawn
existing=$(hyprspace_find_window "$WINDOW_CLASS" "$context_title")
if [[ -n "$existing" ]]; then
  hyprspace_focus_window "$WORKSPACE_NAME" "$existing"
else
  kitty --class "$WINDOW_CLASS" --title "$context_title" --directory "${cwd%/}" "$APP_BIN" &
  if hyprspace_wait_for_window "$WINDOW_CLASS" "$context_title" "${cwd%/}"; then
    new_window=$(hyprspace_find_window "$WINDOW_CLASS" "$context_title")
    if [[ -n "$new_window" ]]; then
      hyprspace_focus_window "$WORKSPACE_NAME" "$new_window"
    else
      hyprspace_show_workspace "$WORKSPACE_NAME"
    fi
  fi
fi
```

## Dependencies

- `hyprctl` - Hyprland IPC client
- `jq` - JSON processor
- `kitty` - Terminal emulator
- `notify-send` - Desktop notifications
- `flock` - File locking utility

## Used By

- `/ai/claude/hyprclaude.sh` - Claude Code modal launcher
- `/tools/lazygit/hyprgit.sh` - Lazygit modal launcher
