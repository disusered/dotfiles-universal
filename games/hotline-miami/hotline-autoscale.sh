#!/bin/bash
# Dynamic resolution launcher for Hotline Miami on Hyprland/Wayland
# Detects the focused monitor's resolution and launches gamescope
# with fixed 1080p internal rendering and dynamic output scaling.

# Game's native resolution — DO NOT CHANGE
# Hotline Miami is designed for 1080p; changing this breaks UI scaling.
GAME_W=1920
GAME_H=1080
GAME_FPS=60

# Detect focused monitor dimensions via Hyprland IPC
if command -v hyprctl &>/dev/null; then
    MONITOR_JSON=$(hyprctl -j monitors | jq '.[] | select(.focused == true)')
    TARGET_W=$(echo "$MONITOR_JSON" | jq -r '.width')
    TARGET_H=$(echo "$MONITOR_JSON" | jq -r '.height')
else
    echo "Warning: hyprctl not found. Defaulting to 1080p output."
    TARGET_W=$GAME_W
    TARGET_H=$GAME_H
fi

# Fallback if detection failed
if [[ -z "$TARGET_W" || "$TARGET_W" == "null" || -z "$TARGET_H" || "$TARGET_H" == "null" ]]; then
    TARGET_W=$GAME_W
    TARGET_H=$GAME_H
fi

echo "Hotline Miami launcher"
echo "  Internal: ${GAME_W}x${GAME_H} @ ${GAME_FPS}fps"
echo "  Output:   ${TARGET_W}x${TARGET_H}"

# Stability environment variables
export ENABLE_GAMESCOPE_WSI=0  # Fixes startup crashes with legacy OpenGL titles
export SteamDeck=1             # Triggers optimized Valve compatibility paths
export LD_PRELOAD=""           # Clears Steam overlay libs (prevents lag bomb)

exec gamescope \
    -w "$GAME_W" -h "$GAME_H" \
    -W "$TARGET_W" -H "$TARGET_H" \
    -r "$GAME_FPS" \
    -f \
    --grab \
    -S fit \
    -F nearest \
    --backend wayland \
    -- "$@"
