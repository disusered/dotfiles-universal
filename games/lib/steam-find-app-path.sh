#!/usr/bin/env bash
# Resolve the Steam library root that holds a given app.
#
# Usage: steam-find-app-path.sh <app_id>
#
# - Prints the library root (the directory containing `steamapps/`) on stdout,
#   e.g. /home/user/.local/share/Steam or /mnt/games/SteamLibrary.
# - Reads the "path" entries out of steamapps/libraryfolders.vdf and returns
#   the first one that actually holds steamapps/appmanifest_<app_id>.acf.
# - Falls back to the default library when libraryfolders.vdf is missing.
# - Exits non-zero when no library holds the app, so callers can decide whether
#   that is fatal (install-time) or merely a warning (launch-time).
#
# Machines differ: a game can live on the internal drive on one box and on a
# secondary library on another. Everything derived from the library root
# (the install dir, the compatdata Proton prefix) has to be resolved, never
# hardcoded.

set -e

APP_ID="${1:?app_id required}"

DEFAULT_LIB="$HOME/.local/share/Steam"
LIBRARYFOLDERS="$DEFAULT_LIB/steamapps/libraryfolders.vdf"

has_app() {
  [ -f "$1/steamapps/appmanifest_${APP_ID}.acf" ]
}

if [ -f "$LIBRARYFOLDERS" ]; then
  while IFS= read -r lib; do
    [ -n "$lib" ] || continue
    if has_app "$lib"; then
      echo "$lib"
      exit 0
    fi
  done < <(grep -oP '"path"\s+"\K[^"]+' "$LIBRARYFOLDERS")
fi

# libraryfolders.vdf absent or unparseable — try the default library directly.
if has_app "$DEFAULT_LIB"; then
  echo "$DEFAULT_LIB"
  exit 0
fi

echo "Error: no Steam library holds app $APP_ID." >&2
echo "Install it from Steam first, then re-run." >&2
exit 1
