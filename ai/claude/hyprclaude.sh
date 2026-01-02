#!/usr/bin/env bash
# Hyprland claude modal launcher - per-Neovim toggle
# Each Neovim gets its own Claude, tracked via state files
# Fallback: per-Kitty Claude if no Neovim running

set -euo pipefail

CLAUDE_BIN="/home/carlos/.local/share/mise/shims/claude"
PREV_WINDOW_FILE="/tmp/claude-prev-window"
STATE_DIR="/tmp/claude-state"
mkdir -p "$STATE_DIR"

# Get active window info
active_info=$(hyprctl activewindow -j)
active_class=$(echo "$active_info" | jq -r '.class')
active_pid=$(echo "$active_info" | jq -r '.pid')

# 1. Toggle OFF: If Claude modal is focused, hide it
if [[ "$active_class" == "claude_modal" ]]; then
    claude_addr=$(echo "$active_info" | jq -r '.address')
    hyprctl dispatch movewindowpixel "0 -2000,address:$claude_addr"
    if [[ -f "$PREV_WINDOW_FILE" ]]; then
        prev_addr=$(cat "$PREV_WINDOW_FILE")
        hyprctl dispatch focuswindow "address:$prev_addr"
    fi
    exit 0
fi

# 2. Determine context from Kitty
context_id=""
cwd="$HOME"
nvim_pid=""

if [[ "$active_class" == "kitty" ]]; then
    # Query Kitty for focused window state
    kitty_state=$(kitty @ --to "unix:@mykitty-$active_pid" ls 2>/dev/null) || \
                 kitty_state=$(kitty @ --to "unix:@mykitty" ls 2>/dev/null) || \
                 kitty_state=""

    if [[ -n "$kitty_state" ]]; then
        # Extract CWD
        cwd=$(echo "$kitty_state" | jq -r '.[] | .tabs[] | .windows[] | select(.is_focused) | .cwd' | head -1)
        [[ -z "$cwd" || "$cwd" == "null" ]] && cwd="$HOME"

        # Extract Neovim PID if running
        nvim_pid=$(echo "$kitty_state" | jq -r '
            .[] | .tabs[] | .windows[] | select(.is_focused) |
            .foreground_processes[] | select(.cmdline[0] == "nvim") | .pid
        ' 2>/dev/null | head -1) || nvim_pid=""
    fi

    # Set context ID based on Neovim or Kitty
    if [[ -n "$nvim_pid" && "$nvim_pid" != "null" ]]; then
        context_id="nvim-$nvim_pid"
    else
        context_id="kitty-$active_pid"
    fi
else
    context_id="generic"
fi

state_file="$STATE_DIR/$context_id"

# 3. Check if Claude exists for this context (via state file)
if [[ -f "$state_file" ]]; then
    claude_addr=$(cat "$state_file")

    # Verify window still exists
    if hyprctl clients -j | jq -e ".[] | select(.address == \"$claude_addr\")" >/dev/null 2>&1; then
        # Window exists - check if hidden (y < 0)
        win_y=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$claude_addr\") | .at[1]")

        if [[ "$win_y" -lt 0 ]]; then
            # Hidden - show it
            echo "$active_info" | jq -r '.address' > "$PREV_WINDOW_FILE"
            hyprctl dispatch focuswindow "address:$claude_addr"
            hyprctl dispatch centerwindow
            # Move cursor to center
            win_info=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$claude_addr\")")
            win_x=$(echo "$win_info" | jq -r '.at[0]')
            win_y=$(echo "$win_info" | jq -r '.at[1]')
            win_w=$(echo "$win_info" | jq -r '.size[0]')
            win_h=$(echo "$win_info" | jq -r '.size[1]')
            cursor_x=$((win_x + win_w / 2))
            cursor_y=$((win_y + win_h / 2))
            hyprctl dispatch movecursor "$cursor_x" "$cursor_y"
        else
            # Visible - just focus it
            echo "$active_info" | jq -r '.address' > "$PREV_WINDOW_FILE"
            hyprctl dispatch focuswindow "address:$claude_addr"
        fi
        exit 0
    else
        # Window no longer exists - clean up state
        rm -f "$state_file"
    fi
fi

# 4. Spawn new Claude
echo "$active_info" | jq -r '.address' > "$PREV_WINDOW_FILE"

# Socket path for Neovim communication (Kitty will append its PID, but Neovim can glob for it)
socket_base="/tmp/claude-$context_id"

kitty --class claude_modal \
      -o "listen_on=unix:$socket_base.sock" \
      -o "allow_remote_control=yes" \
      --title "Claude Code [$context_id]" \
      --directory "$cwd" \
      --hold "$CLAUDE_BIN" &

# Wait for window to appear and save its address
for _ in {1..30}; do
    sleep 0.1
    # Find the newest claude_modal window
    new_addr=$(hyprctl clients -j | jq -r '.[] | select(.class == "claude_modal") | .address' | while read addr; do
        # Check if this address is already tracked
        found=false
        for sf in "$STATE_DIR"/*; do
            [[ -f "$sf" ]] && [[ "$(cat "$sf")" == "$addr" ]] && found=true && break
        done
        $found || echo "$addr"
    done | head -1)

    if [[ -n "$new_addr" ]]; then
        echo "$new_addr" > "$state_file"
        break
    fi
done

exit 0
