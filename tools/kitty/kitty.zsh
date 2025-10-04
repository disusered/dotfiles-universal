# Only configure if running in Kitty
if [[ "$TERM" != "xterm-kitty" ]]; then
  return
fi

# Function to reload Kitty configuration
reload-kitty-config() {
  if [[ -n "$KITTY_PID" ]]; then
    kill -SIGUSR1 "$KITTY_PID"
    echo "Kitty config reloaded (PID: $KITTY_PID)"
  else
    local kitty_pid=$(pgrep -x kitty | head -1)
    if [[ -n "$kitty_pid" ]]; then
      kill -SIGUSR1 "$kitty_pid"
      echo "Kitty config reloaded (PID: $kitty_pid)"
    else
      echo "Error: Could not find Kitty process"
      return 1
    fi
  fi
}

# ZLE widget wrapper
reload-kitty-config-widget() {
  reload-kitty-config
  zle reset-prompt
}

# Register ZLE widget
zle -N reload-kitty-config-widget

# Bind to Ctrl+B r (tmux/wezterm style prefix)
bindkey -s '^Br' 'reload-kitty-config\n'
