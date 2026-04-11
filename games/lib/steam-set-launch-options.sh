#!/usr/bin/env bash
# Patch a game's LaunchOptions in Steam's localconfig.vdf.
#
# Usage: steam-set-launch-options.sh <app_id> <launch_opts> [game_label]
#
# - Replaces an existing LaunchOptions entry for the app id, preserving tabs.
# - Inserts LaunchOptions before the closing brace of the app block when the
#   key is absent (the common case for a game whose launch options have never
#   been set manually before).
# - Refuses to touch the file while Steam is running, since Steam rewrites
#   localconfig.vdf on shutdown and would clobber our changes.
# - Exits 0 with a warning when localconfig.vdf cannot be found or Steam is
#   running, so Rotz installs are not aborted by a missing / busy Steam.

set -e

APP_ID="${1:?app_id required}"
LAUNCH_OPTS="${2:?launch_opts required}"
GAME_LABEL="${3:-$APP_ID}"

LOCALCONFIG=$(find "$HOME/.local/share/Steam/userdata" -name localconfig.vdf -print -quit 2>/dev/null)

if [ -z "$LOCALCONFIG" ]; then
  echo "Warning: Steam localconfig.vdf not found. Set launch options manually:"
  echo "  $LAUNCH_OPTS"
  exit 0
fi

if pgrep -x steam >/dev/null 2>&1; then
  echo "Warning: Steam is running. Close Steam before installing to set launch options."
  echo "  Launch options to set manually: $LAUNCH_OPTS"
  exit 0
fi

awk -v app="\"$APP_ID\"" -v opts="$LAUNCH_OPTS" '
  !in_app && $0 ~ "^[[:space:]]*" app "[[:space:]]*$" {
    in_app=1; found=0; next_is_open=1; print; next
  }
  in_app && next_is_open && /^[[:space:]]*\{/ {
    depth=1; next_is_open=0; print; next
  }
  in_app && /\{/ { depth++ }
  in_app && /"LaunchOptions"/ {
    sub(/"LaunchOptions"[[:space:]]*"[^"]*"/, "\"LaunchOptions\"\t\t\"" opts "\"")
    found=1
  }
  in_app && /^[[:space:]]*\}/ {
    depth--
    if (depth==0) {
      if (!found) {
        match($0, /^[[:space:]]*/)
        indent = substr($0, 1, RLENGTH) "\t"
        print indent "\"LaunchOptions\"\t\t\"" opts "\""
      }
      in_app=0
    }
  }
  { print }
' "$LOCALCONFIG" > "${LOCALCONFIG}.tmp" && mv "${LOCALCONFIG}.tmp" "$LOCALCONFIG"

echo "Steam launch options set for $GAME_LABEL ($APP_ID): $LAUNCH_OPTS"
