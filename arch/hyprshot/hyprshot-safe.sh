#!/usr/bin/env bash

# hyprshot's --freeze spawns `hyprpicker -r -z` as a Wayland overlay that
# paints a frozen snapshot of the screen. /usr/bin/hyprshot uses `set -e`,
# so any non-zero exit from slurp/hyprctl/grim/jq/wl-copy aborts the script
# before its cleanup runs — leaving hyprpicker alive and the desktop stuck
# on the frozen frame. This wrapper guarantees hyprpicker (and any stray
# slurp) is killed no matter how hyprshot exits.

cleanup() {
    pkill -x hyprpicker 2>/dev/null
    pkill -x slurp 2>/dev/null
}
trap cleanup EXIT INT TERM HUP

hyprshot "$@"
