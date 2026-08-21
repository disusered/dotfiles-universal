#!/usr/bin/env bash
# Swap SkyrimSE.exe for skse64_loader.exe in the command Steam hands over.
#
# Usage (as a Steam launch-option wrapper):
#   scb -- gamemoderun skyrim-skse-launch %command%
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

  # Steam's registered executable for 489830 is SkyrimSELauncher.exe, not
  # SkyrimSE.exe — the Bethesda launcher is what %command% ends with, and it
  # spawns the game itself. Matching only SkyrimSE.exe meant this shim never
  # fired: the launcher ran, SKSE never loaded, and SSE Engine Fixes' preloader
  # (which the game loads on its own via the d3dx9_42.dll hijack) applied its
  # memory patches into a process with no SKSE behind them, and it crashed on
  # Play. Swapping the launcher is also what removes its oversized resolution
  # dialog, since SKSE goes straight to the game.
  #
  # Matched case-insensitively: Wine is case-insensitive, this filesystem is
  # not, and Steam's casing has changed before.
  case ${arg,,} in
    *skyrimselauncher.exe | *skyrimse.exe) ;;
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
  echo "skyrim-skse-launch: no Skyrim executable in command; passing through" >&2
fi

gaming_session="$HOME/.local/bin/gaming-session"
host_policy=${SKYRIM_HOST_WORKLOAD_POLICY:-normal}

case $host_policy in
  normal)
    # run-if-armed quiesces nothing unless a profile was explicitly armed, so
    # ordinary play is a pass-through. It used to hang here: gaming-session took
    # its session lock before checking the armed flag, and a descriptor leaked
    # into podman's surviving helpers had left that lock held forever, so Proton
    # never started. That path now takes no lock when nothing is armed, waits a
    # bounded time when something is, and launches the game regardless.
    if [ -x "$gaming_session" ]; then
      exec "$gaming_session" run-if-armed --profile co-located -- "${args[@]}"
    fi
    ;;
  quiesced)
    if [ ! -x "$gaming_session" ]; then
      echo "skyrim-skse-launch: quiesced host policy requires $gaming_session" >&2
      exit 1
    fi
    exec "$gaming_session" run --profile co-located -- "${args[@]}"
    ;;
  *)
    echo "skyrim-skse-launch: invalid SKYRIM_HOST_WORKLOAD_POLICY=$host_policy" >&2
    exit 2
    ;;
esac

exec "${args[@]}"
