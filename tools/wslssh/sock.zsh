# https://stuartleeks.com/posts/wsl-ssh-key-forward-to-windows/

# Configure ssh forwarding
export SSH_AUTH_SOCK=$HOME/.ssh/agent.sock

# Use a lock file to prevent race conditions in multi-shell environments
LOCK_FILE="$HOME/.ssh/agent.lock"
SOCAT_PID_FILE="$HOME/.ssh/socat.pid"

# Clean up old lock file if it exists and is stale
cleanup_old_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
        if [[ $lock_age -gt 30 ]]; then  # Lock is older than 30 seconds
            rm -f "$LOCK_FILE"
        fi
    fi
}

# Check if socat relay is already working properly
is_relay_working() {
    # Check if socket exists and is functional
    [[ -S "$SSH_AUTH_SOCK" ]] && timeout 2 ssh-add -l >/dev/null 2>&1
}

# Get PID of socat process if it exists
get_socat_pid() {
    ps -auxww | grep "[s]ocat.*npiperelay" | awk '{print $2}' | head -1
}

# Initialize SSH agent relay if needed
init_ssh_agent_relay() {
    # Clean up old lock first
    cleanup_old_lock

    # Check if relay is already working
    if is_relay_working; then
        return 0
    fi

    # Try to acquire lock
    if (set -o noclobber; echo "$$" > "$LOCK_FILE") 2>/dev/null; then
        trap 'rm -f "$LOCK_FILE"' EXIT

        # Double-check after acquiring lock
        if is_relay_working; then
            rm -f "$LOCK_FILE"
            return 0
        fi

        # Clean up any existing socket or hanging process
        if [[ -S "$SSH_AUTH_SOCK" ]]; then
            rm -f "$SSH_AUTH_SOCK"
        fi

        # Kill any existing socat processes that might be hanging
        local current_pid=$(get_socat_pid)
        if [[ -n "$current_pid" ]]; then
            # Check if it's actually our managed process
            if [[ -f "$SOCAT_PID_FILE" ]] && [[ "$(cat "$SOCAT_PID_FILE" 2>/dev/null)" = "$current_pid" ]]; then
                kill "$current_pid" 2>/dev/null || true
            fi
        fi

        # Start the relay
        (setsid socat UNIX-LISTEN:$SSH_AUTH_SOCK,fork EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &) >/dev/null 2>&1

        # Store the PID
        local new_pid=$(get_socat_pid)
        if [[ -n "$new_pid" ]]; then
            echo "$new_pid" > "$SOCAT_PID_FILE"
        fi

        # Release lock
        rm -f "$LOCK_FILE"
        trap - EXIT
    fi
}

# Initialize the relay
init_ssh_agent_relay
