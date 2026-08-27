#!/usr/bin/env bash
# Restore the pinned Skyrim SE runtime (1.6.1170) after Steam updates the game.
#
#   skyrim-restore-runtime --status    report drift; touch nothing
#   skyrim-restore-runtime --dry-run   say what would be copied; touch nothing
#   skyrim-restore-runtime             restore
#
# Why this shape:
#
# Every SKSE plugin is compiled against one runtime, so a Bethesda patch
# disables the whole mod set at once. The recovery is to put Valve's own
# 1.6.1170 files back over the install — see README.md, "The game version is
# pinned to 1.6.1170". The manifest IDs live in runtime-pin.tsv, not in prose.
#
# The download itself is NOT scripted, and that is deliberate. `download_depot`
# is a command in the Steam client's own console; the alternative, steamcmd,
# would need this account's Steam credentials handed to a script. So the
# download is a *checked precondition*: this prints the exact lines to paste and
# refuses to continue until the depot content is on disk and complete.
#
# Nothing here deletes a game file. Restoring is `cp` over the install, so mod
# files in Data/ are never touched — only the vanilla files the update replaced.

set -uo pipefail

APP_ID=489830
MODULE_DIR="${SKYRIM_MODULE_DIR:-$HOME/.dotfiles/games/skyrim-special-edition}"
PIN="${SKYRIM_RUNTIME_PIN:-$MODULE_DIR/runtime-pin.tsv}"
STATE_DIR="${SKYRIM_MOD_STATE:-$HOME/.local/state/skyrim-mods}"
PINNED_VERSION="${SKYRIM_PINNED_VERSION:-1.6.1170.0}"

# Where `download_depot` puts things. Note `ubuntu12_32`, not the
# steamapps/content path next to the install that you would guess — the Steam
# console writes relative to the 32-bit client directory.
DEPOT_ROOT="${SKYRIM_DEPOT_ROOT:-$HOME/.local/share/Steam/ubuntu12_32/steamapps/content/app_$APP_ID}"

MODE=restore
case "${1:-}" in
  --status)  MODE=status ;;
  --dry-run) MODE=dryrun ;;
  --help|-h) sed -n '2,24p' "$0"; exit 0 ;;
  "")        ;;
  *)         echo "unknown option: $1" >&2; exit 2 ;;
esac

die()  { echo "Error: $*" >&2; exit 1; }
note() { echo "  $*"; }

# Read the version resource out of a Windows PE. It is UTF-16LE, so plain
# `strings` misses it on some builds; try wide first, then narrow.
exe_version() {
  local exe=$1
  [ -f "$exe" ] || return 1
  { strings -el "$exe" 2>/dev/null; strings "$exe" 2>/dev/null; } \
    | grep -m1 -E '^1\.[0-9]+\.[0-9]+\.[0-9]+$'
}

[ -f "$PIN" ] || die "runtime pin not found: $PIN"

if ! LIB=$("$MODULE_DIR/../lib/steam-find-app-path.sh" "$APP_ID" 2>/dev/null); then
  die "Skyrim SE ($APP_ID) not found in any Steam library"
fi
GAME_DIR="${SKYRIM_GAME_DIR:-$LIB/steamapps/common/Skyrim Special Edition}"
ACF="$LIB/steamapps/appmanifest_$APP_ID.acf"
[ -d "$GAME_DIR" ] || die "game directory missing: $GAME_DIR"

# ── read the pin ──────────────────────────────────────────────────────────
declare -a DEPOTS=() MANIFESTS=() FILECOUNTS=()
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*|depot$'\t'*) continue ;; esac
  mapfile -t -d $'\t' F < <(printf '%s' "$line")
  DEPOTS+=("${F[0]-}"); MANIFESTS+=("${F[1]-}"); FILECOUNTS+=("${F[2]-}")
done < "$PIN"
[ ${#DEPOTS[@]} -gt 0 ] || die "no depot rows in $PIN"

# ── report drift ──────────────────────────────────────────────────────────
installed_version=$(exe_version "$GAME_DIR/SkyrimSE.exe" || true)
acf_build=$(awk -F'"' '/"buildid"/{print $4}' "$ACF" 2>/dev/null)
acf_target=$(awk -F'"' '/"TargetBuildID"/{print $4}' "$ACF" 2>/dev/null)

echo "Skyrim SE runtime pin"
note "game dir          $GAME_DIR"
note "pinned runtime    $PINNED_VERSION"
note "installed runtime ${installed_version:-<SkyrimSE.exe missing>}"
note "acf buildid       ${acf_build:-?}   TargetBuildID ${acf_target:-?}"
if [ -n "$acf_target" ] && [ "$acf_target" != 0 ] && [ "$acf_target" != "$acf_build" ]; then
  note "Steam wants to move this install to build $acf_target."
  note "Restoring underneath a running download just gets overwritten — pause it first."
fi
echo

if [ "$installed_version" = "$PINNED_VERSION" ] && [ "$MODE" = status ]; then
  echo "Runtime matches the pin. Nothing to restore."
  exit 0
fi

# ── precondition: the depot content has to be there, and complete ─────────
missing_depots=()
short_depots=()
for i in "${!DEPOTS[@]}"; do
  d="${DEPOTS[$i]}" want="${FILECOUNTS[$i]}"
  dir="$DEPOT_ROOT/depot_$d"
  if [ ! -d "$dir" ]; then missing_depots+=("$i"); continue; fi
  have=$(find "$dir" -type f | wc -l)
  # A depot still downloading has fewer files than the console announced.
  # Copying that over the install produces a subtly broken game that looks
  # installed, so refuse rather than warn.
  if [ -n "$want" ] && [ "$have" -lt "$want" ]; then short_depots+=("$i:$have/$want"); fi
done

if [ ${#missing_depots[@]} -gt 0 ] || [ ${#short_depots[@]} -gt 0 ]; then
  if [ ${#short_depots[@]} -gt 0 ]; then
    echo "Depot content incomplete — still downloading?"
    for s in "${short_depots[@]}"; do
      i=${s%%:*}; note "depot ${DEPOTS[$i]}: ${s#*:} files"
    done
    echo
  fi
  echo "Download the pinned depots from Valve first. In the Steam client:"
  echo
  echo "    steam -console          # restart Steam with this; the CONSOLE tab"
  echo "                            # appears in the header, beside Library"
  echo
  for i in "${!DEPOTS[@]}"; do
    printf '    download_depot %s %s %s\n' "$APP_ID" "${DEPOTS[$i]}" "${MANIFESTS[$i]}"
  done
  echo
  note "they land in $DEPOT_ROOT"
  note "then re-run: skyrim-restore-runtime"
  exit 1
fi

# ── verify the depot before trusting it ───────────────────────────────────
# The exe depot is the only one that decides the version. Check it *before*
# copying anything: a wrong manifest in the pin would otherwise be discovered
# only after 12 GB had been laid over the install.
depot_exe=$(find "$DEPOT_ROOT" -name SkyrimSE.exe -type f | head -1)
[ -n "$depot_exe" ] || die "no SkyrimSE.exe in $DEPOT_ROOT — wrong manifest in $PIN?"
depot_version=$(exe_version "$depot_exe" || true)
if [ "$depot_version" != "$PINNED_VERSION" ]; then
  die "depot SkyrimSE.exe is $depot_version, pin expects $PINNED_VERSION — refusing to copy"
fi
note "depot SkyrimSE.exe verified: $depot_version"
echo

if [ "$MODE" = status ]; then
  echo "Depot content present and verified. Run without --status to restore."
  exit 0
fi

# ── restore ───────────────────────────────────────────────────────────────
for i in "${!DEPOTS[@]}"; do
  d="${DEPOTS[$i]}"
  src="$DEPOT_ROOT/depot_$d"
  if [ "$MODE" = dryrun ]; then
    echo "WOULD COPY  depot $d ($(find "$src" -type f | wc -l) files) -> $GAME_DIR"
    continue
  fi
  echo "COPY  depot $d -> $GAME_DIR"
  # cp, never rsync --delete: mod files living beside vanilla ones in Data/
  # must survive. -a to keep the depot's timestamps, which is what makes a
  # later `ls -la` able to tell restored vanilla files from mod files.
  cp -a "$src/." "$GAME_DIR/" || die "copy of depot $d failed"
done

if [ "$MODE" = dryrun ]; then
  echo
  echo "Dry run: nothing was copied."
  exit 0
fi

echo

# ── re-assert the things the copy undoes ──────────────────────────────────
# The depot carries the intro video, so restoring puts it back. Same single mv
# the module's install step does.
LOGO="$GAME_DIR/Data/Video/BGS_Logo.bik"
if [ -f "$LOGO" ]; then
  bak="$LOGO.bak"; n=2
  while [ -e "$bak" ]; do bak="$LOGO.bak$n"; n=$((n + 1)); done
  mv "$LOGO" "$bak" && note "intro video disabled ($(basename "$LOGO") -> $(basename "$bak"))"
fi

# Refresh the vanilla texture baseline from what was just restored. CSSET
# replaces Skyrim - Textures0-8.bsa in place, so this is the only copy of the
# untouched originals for that build, and it is what makes CSSET removable.
BASELINE="$STATE_DIR/baseline-textures-$(echo "$PINNED_VERSION" | cut -d. -f1-3)"
mkdir -p "$BASELINE"
# cp -an exits 0 whether it copied or declined to clobber, so test for the
# destination instead of trusting the exit status — otherwise every run claims
# to have refreshed a baseline it actually left alone.
copied=0 kept=0
for t in "$GAME_DIR"/Data/Skyrim\ -\ Textures*.bsa; do
  [ -e "$t" ] || continue
  if [ -e "$BASELINE/$(basename "$t")" ]; then
    kept=$((kept + 1))
  elif cp -a "$t" "$BASELINE/" 2>/dev/null; then
    copied=$((copied + 1))
  fi
done
if [ "$copied" -gt 0 ] || [ "$kept" -gt 0 ]; then
  note "texture baseline $BASELINE: $copied added, $kept already present"
fi

# ── verify what landed ────────────────────────────────────────────────────
echo
final_version=$(exe_version "$GAME_DIR/SkyrimSE.exe" || true)
if [ "$final_version" != "$PINNED_VERSION" ]; then
  die "restore finished but SkyrimSE.exe reports '${final_version:-<missing>}', expected $PINNED_VERSION"
fi
echo "Runtime restored: SkyrimSE.exe $final_version"

# SKSE lives beside the exe and is not in any depot, so the update may have
# deleted it without this being able to put it back.
if [ ! -f "$GAME_DIR/skse64_loader.exe" ]; then
  note "skse64_loader.exe is missing — reinstall SKSE with: skyrim-install-mods"
fi

echo
echo "Next:"
note "reclaim ~12 GB:  rm -rf '$DEPOT_ROOT'"
note "re-apply mods the update removed: skyrim-install-mods --dry-run, then for real"
note "do NOT use Steam's 'Verify integrity of game files' — that is what breaks the pin"
