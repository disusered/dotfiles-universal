#!/usr/bin/env bash
# Swap SkyrimSE.exe for skse64_loader.exe in the command Steam hands over.
#
# Usage (as a Steam launch-option wrapper):
#   scb -- skyrim-skse-launch %command%
#
# SKSE runs by launching its own loader instead of the game binary. The two
# usual ways to arrange that are both bad here:
#
#   - Renaming SkyrimSE.exe and dropping the loader in its place breaks on
#     every Steam file-verify and every game update.
#   - Adding skse64_loader.exe as a separate non-Steam game means hand-managing
#     STEAM_COMPAT_DATA_PATH so it lands in the same Proton prefix, and it
#     drops out of this repo's control entirely.
#
# So instead this rewrites the exe argument in place, the same way
# hotline-autoscale and pst-ee-launch wrap their games. It sits *inside*
# ScopeBuddy rather than replacing it, so SCB_PRE_COMMAND (INI generation) and
# SCB_AUTO_RES (resolution detection) keep working — dropping scb would take
# both with it.
#
# Never blocks a launch: if the loader is missing, or the command does not look
# the way we expect, the original command runs untouched and the game starts
# vanilla.

set -uo pipefail

if [ "$#" -eq 0 ]; then
  echo "skyrim-skse-launch: no command given" >&2
  exit 2
fi

args=("$@")
matched=0

for i in "${!args[@]}"; do
  arg=${args[$i]}

  # Match the game binary regardless of case; Wine paths are case-insensitive
  # but this filesystem is not, and Steam's casing has changed before.
  case ${arg,,} in
    *skyrimse.exe) ;;
    *) continue ;;
  esac

  matched=1
  dir=$(dirname -- "$arg")
  loader="$dir/skse64_loader.exe"

  if [ -f "$loader" ]; then
    args[i]=$loader
    echo "skyrim-skse-launch: launching SKSE ($loader)" >&2
  else
    echo "skyrim-skse-launch: no skse64_loader.exe beside $arg; starting vanilla" >&2
  fi
  break
done

if [ "$matched" -eq 0 ]; then
  echo "skyrim-skse-launch: SkyrimSE.exe not found in command; passing through" >&2
fi

exec "${args[@]}"
