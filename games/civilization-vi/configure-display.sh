#!/usr/bin/env bash

set -euo pipefail

WIDTH=${1:?display width required}
HEIGHT=${2:?display height required}

if [[ ! $WIDTH =~ ^[0-9]+$ || ! $HEIGHT =~ ^[0-9]+$ ]]; then
  echo "Error: invalid Civ VI display size: ${WIDTH}x${HEIGHT}" >&2
  exit 1
fi

OPTIONS_FILE=${CIV6_OPTIONS_FILE:-"$HOME/.local/share/Steam/steamapps/compatdata/289070/pfx/drive_c/users/steamuser/AppData/Local/Firaxis Games/Sid Meier's Civilization VI/AppOptions.txt"}

if [[ ! -f $OPTIONS_FILE ]]; then
  echo "Warning: Civ VI has not created AppOptions.txt yet; display settings will be applied after its first run." >&2
  exit 0
fi

sed -i \
  -e "s/^RenderWidth .*/RenderWidth $WIDTH/" \
  -e "s/^RenderHeight .*/RenderHeight $HEIGHT/" \
  -e 's/^FullScreen .*/FullScreen 2/' \
  -e 's/^MouseGrab .*/MouseGrab 2/' \
  "$OPTIONS_FILE"

echo "Civ VI display configured: ${WIDTH}x${HEIGHT}, borderless, mouse grabbed"
