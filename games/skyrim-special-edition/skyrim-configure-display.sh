#!/usr/bin/env bash
# Render Skyrim SE's INIs into its Proton prefix, sized for whichever machine
# and monitor the game is being launched on.
#
# Usage: skyrim-configure-display <width> <height>
#
# Called from ScopeBuddy's SCB_PRE_COMMAND, which supplies the focused
# monitor's resolution via SCB_AUTO_RES. The INIs are *generated*, not
# symlinked, because the two machines this repo serves disagree about
# resolution, aspect ratio and GPU class — a committed SkyrimPrefs.ini would
# be wrong on one of them by construction. Regenerating also means the Skyrim
# launcher's hardware detection can clobber the files as much as it likes.
#
# Overrides:
#   SKYRIM_FOV    force a field of view instead of deriving one from the
#                 aspect ratio, e.g. SKYRIM_FOV=90
#   SKYRIM_TIER   force `igpu` or `dgpu` instead of detecting the GPU

set -euo pipefail

APP_ID=489830
TEMPLATE_DIR="${SKYRIM_TEMPLATE_DIR:-$HOME/.dotfiles/games/skyrim-special-edition}"

WIDTH=${1:?display width required}
HEIGHT=${2:?display height required}

if [[ ! $WIDTH =~ ^[0-9]+$ || ! $HEIGHT =~ ^[0-9]+$ ]]; then
  echo "Error: invalid Skyrim display size: ${WIDTH}x${HEIGHT}" >&2
  exit 1
fi

# Never block a launch. If the library or the templates cannot be found, say so
# and let the game start with whatever INIs are already in the prefix.
if ! LIB=$("$HOME/.dotfiles/games/lib/steam-find-app-path.sh" "$APP_ID" 2>/dev/null); then
  echo "Warning: Skyrim SE ($APP_ID) not found in any Steam library; leaving INIs alone." >&2
  exit 0
fi

INI_DIR="$LIB/steamapps/compatdata/$APP_ID/pfx/drive_c/users/steamuser/Documents/My Games/Skyrim Special Edition"

# Pick the quality tier. Anything with a discrete AMD (1002) or NVIDIA (10de)
# display controller gets the High-derived preset; everything else (Intel Iris
# Xe on the work machine) gets the Medium-derived one.
if [[ -n ${SKYRIM_TIER:-} ]]; then
  TIER=$SKYRIM_TIER
elif lspci -nn 2>/dev/null | grep -E 'VGA compatible controller|3D controller' \
  | grep -qE '\[(1002|10de):'; then
  TIER=dgpu
else
  TIER=igpu
fi

PREFS_TEMPLATE="$TEMPLATE_DIR/SkyrimPrefs.$TIER.ini"
SKYRIM_TEMPLATE="$TEMPLATE_DIR/Skyrim.ini"

for template in "$PREFS_TEMPLATE" "$SKYRIM_TEMPLATE"; do
  if [[ ! -f $template ]]; then
    echo "Warning: missing template $template; leaving Skyrim INIs alone." >&2
    exit 0
  fi
done

# Field of view. Vanilla is 80 degrees at 16:9. Widen it Hor+ for wider
# displays so the extra width shows more world rather than a stretched one,
# and never narrow it below vanilla. Clamped at 110 because the fisheye on a
# 32:9 panel is worse than the cropped view.
if [[ -n ${SKYRIM_FOV:-} ]]; then
  FOV=$SKYRIM_FOV
else
  FOV=$(awk -v w="$WIDTH" -v h="$HEIGHT" 'BEGIN {
    pi = atan2(0, -1); base = 80; half = (base / 2) * pi / 180
    fov = 2 * atan2(sin(half) / cos(half) * (w / h) / (16 / 9), 1) * 180 / pi
    if (fov < base) fov = base
    if (fov > 110) fov = 110
    printf "%.4f", fov
  }')
fi

mkdir -p "$INI_DIR"

# Drop the read-only bit this script set on its last run before rewriting.
for f in SkyrimPrefs.ini Skyrim.ini; do
  if [ -e "$INI_DIR/$f" ]; then
    chmod u+w "$INI_DIR/$f"
  fi
done

# Write fresh files rather than editing in place: in-place edits on a config
# that may itself be a symlink either detach the link or write back into the
# dotfiles repo, and both are traps.
sed -e "s/@WIDTH@/$WIDTH/g" -e "s/@HEIGHT@/$HEIGHT/g" \
  "$PREFS_TEMPLATE" > "$INI_DIR/SkyrimPrefs.ini"
sed -e "s/@FOV@/$FOV/g" \
  "$SKYRIM_TEMPLATE" > "$INI_DIR/Skyrim.ini"

# Lock the files. Generating them is not enough on its own — two things
# overwrite them *after* this hook runs, and both were caught doing it on the
# first real launch:
#
#   1. Steam's install script. installscript.vdf has a "Copy Folders" rule that
#      copies <gamedir>/Skyrim/SkyrimPrefs.ini over the top of My Games.
#   2. SkyrimSELauncher.exe's "detecting video hardware" pass, which wrote the
#      full Ultra.ini preset — 4096 shadow maps and volumetric quality 2 — onto
#      a machine with Intel integrated graphics.
#
# Wine surfaces a Unix-unwritable file as a read-only Windows file, so both
# writes fail harmlessly and the settings chosen here are what the game loads.
# Steam Cloud is not a concern: for this title it syncs only Saves/*.ess.
chmod a-w "$INI_DIR/SkyrimPrefs.ini" "$INI_DIR/Skyrim.ini"

echo "Skyrim SE configured: ${WIDTH}x${HEIGHT}, $TIER preset, FOV $FOV, borderless (INIs locked read-only)"
