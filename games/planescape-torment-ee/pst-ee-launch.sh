#!/bin/bash
# Planescape: Torment EE launcher — native-resolution gamescope + libssl 1.0 shim
#
# Forces the 64-bit native binary (Torment64), resolves the legacy
# libssl.so.1.0.0 / libcrypto.so.1.0.0 dependency via the AUR openssl-1.0
# package, and hands off to gamescope at the focused monitor's native
# resolution. PST:EE supports arbitrary widescreen (incl. 3440x1440)
# natively, so rendering 1:1 avoids the letterboxing that `-S integer`
# causes when the monitor size is not an integer multiple of a fixed
# internal render.

GAME_FPS=60

# libssl.so.1.0.0 / libcrypto.so.1.0.0 shim (AUR: openssl-1.0).
# Package layout varies between revisions; probe common locations.
for dir in /usr/lib/openssl-1.0 /usr/lib; do
    if [[ -e "$dir/libssl.so.1.0.0" ]]; then
        export LD_LIBRARY_PATH="$dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        break
    fi
done

# Detect focused monitor dimensions via Hyprland IPC
if command -v hyprctl &>/dev/null; then
    MONITOR_JSON=$(hyprctl -j monitors | jq '.[] | select(.focused == true)')
    MON_W=$(echo "$MONITOR_JSON" | jq -r '.width')
    MON_H=$(echo "$MONITOR_JSON" | jq -r '.height')
fi

# Fallback if detection failed
[[ -z "$MON_W" || "$MON_W" == "null" ]] && MON_W=1920
[[ -z "$MON_H" || "$MON_H" == "null" ]] && MON_H=1080

# Force the 64-bit binary when Steam passes the 32-bit one
args=()
for a in "$@"; do
    if [[ "$a" == */Torment && -f "${a}64" ]]; then
        args+=("${a}64")
    else
        args+=("$a")
    fi
done

echo "Planescape: Torment EE launcher"
echo "  Render: ${MON_W}x${MON_H} @ ${GAME_FPS}fps (native, 1:1)"

# Stability environment variables
export ENABLE_GAMESCOPE_WSI=0  # legacy GL safety, matches hotline-miami
export LD_PRELOAD=""           # clears Steam overlay libs (prevents lag bomb)

exec gamescope \
    -w "$MON_W" -h "$MON_H" \
    -W "$MON_W" -H "$MON_H" \
    -r "$GAME_FPS" \
    -f \
    --grab \
    --backend wayland \
    -- "${args[@]}"
