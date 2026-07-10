#!/usr/bin/env sh

# 1. Check if hyprpicker is already running.
# If yes, exit silently to prevent stacking instances.
if pgrep -x hyprpicker >/dev/null; then
  exit 0
fi

# 2. Turn off shader for color accuracy
active_shader="$(hyprshade current 2>/dev/null || true)"
hyprshade off

# 3. Launch the picker
# We simply wait for this command to finish (whether success or cancelled via Esc)
hyprpicker --autocopy --format=hex

# 4. Restore the shader
# This runs regardless of whether you picked a color or cancelled,
# ensuring you aren't left with a manually enabled filter stuck off.
if [ -n "$active_shader" ]; then
  hyprshade on "$active_shader"
fi
