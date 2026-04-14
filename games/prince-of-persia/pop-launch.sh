#!/bin/bash
# Prince of Persia: The Sands of Time launcher — gamescope wrapper
#
# Wraps Proton's %command% in a gamescope session at the focused monitor's
# native resolution. Solves two problems:
#   1. Hyprland tiling — POP as a raw XWayland window falls into dwindle
#      layout; gamescope becomes a single class=gamescope window that
#      arch/steam/steam.conf floats/centers.
#   2. Steam Input routing — Steam Input decides whether to forward DS4
#      inputs to the Valve virtual XInput pad based on X focus tracking.
#      Hyprland's XWayland focus propagation is flaky; gamescope gives
#      Steam a clean, isolated X display to target.
#
# Internal render resolution is fixed by pop.ini at 3440x1440; gamescope
# scales to monitor native if they differ.

if command -v hyprctl &>/dev/null; then
    MONITOR_JSON=$(hyprctl -j monitors | jq '.[] | select(.focused == true)')
    MON_W=$(echo "$MONITOR_JSON" | jq -r '.width')
    MON_H=$(echo "$MONITOR_JSON" | jq -r '.height')
fi

[[ -z "$MON_W" || "$MON_W" == "null" ]] && MON_W=1920
[[ -z "$MON_H" || "$MON_H" == "null" ]] && MON_H=1080

echo "Prince of Persia: SoT launcher"
echo "  Render: ${MON_W}x${MON_H} via gamescope"

export ENABLE_GAMESCOPE_WSI=0
export LD_PRELOAD=""

exec gamescope \
    -w "$MON_W" -h "$MON_H" \
    -W "$MON_W" -H "$MON_H" \
    -f \
    --grab \
    --backend wayland \
    -- "$@"
