#!/usr/bin/env bash
# Re-apply wallpaper after monitor changes.

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
LOCK="$XDG_RUNTIME_DIR/wallpaper-listener.lock"

apply_wallpaper() {
  (
    # Display transitions emit a burst of output events. Let the outputs settle
    # and restart hyprpaper only once for the whole burst.
    flock --nonblock 9 || return
    sleep 2
    cfg wallpaper --apply
  ) 9>"$LOCK"
}

socat -u "UNIX-CONNECT:$SOCKET" - | while IFS='>>' read -r event _data; do
  case "$event" in
    monitoradded*|monitorremoved*)
      apply_wallpaper &
      ;;
  esac
done
