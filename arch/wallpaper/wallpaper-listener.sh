#!/usr/bin/env bash
# Re-apply wallpaper on monitor add/remove

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -u "UNIX-CONNECT:$SOCKET" - | while IFS='>>' read -r event data; do
  case "$event" in
    monitoradded*|monitorremoved*)
      cfg wallpaper --apply
      ;;
  esac
done
