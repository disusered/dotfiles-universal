#!/usr/bin/env bash
# Install the signed Arch gamescope build that keeps Skyrim's mouse working.
set -euo pipefail

VERSION=3.16.28-1
TOOLS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/skyrim-performance/tools"
ROOT="$TOOLS_DIR/gamescope-$VERSION-x86_64"
URL="https://archive.archlinux.org/packages/g/gamescope/gamescope-$VERSION-x86_64.pkg.tar.zst"

if [[ -x $ROOT/usr/bin/gamescope && -x $ROOT/usr/bin/gamescopereaper &&
      -d $ROOT/usr/share/gamescope/scripts &&
      -f $ROOT/gamescope.pkg.tar.zst && -f $ROOT/gamescope.pkg.tar.zst.sig ]]; then
  pacman-key --verify "$ROOT/gamescope.pkg.tar.zst.sig" "$ROOT/gamescope.pkg.tar.zst"
  exit 0
fi

mkdir -p "$TOOLS_DIR"
TMP=$(mktemp -d "$TOOLS_DIR/.gamescope-$VERSION.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/gamescope.pkg.tar.zst"
curl -fsSL "$URL.sig" -o "$TMP/gamescope.pkg.tar.zst.sig"
pacman-key --verify "$TMP/gamescope.pkg.tar.zst.sig" "$TMP/gamescope.pkg.tar.zst"
bsdtar -xf "$TMP/gamescope.pkg.tar.zst" -C "$TMP"
[[ -x $TMP/usr/bin/gamescope && -x $TMP/usr/bin/gamescopereaper &&
   -d $TMP/usr/share/gamescope/scripts ]]
"$TMP/usr/bin/gamescope" --version 2>&1 | grep -Fq 'gamescope version 3.16.28'

if [[ -e $ROOT ]]; then
  echo "Existing incomplete gamescope pin at $ROOT; inspect it before reinstalling" >&2
  exit 1
fi
mv -- "$TMP" "$ROOT"
trap - EXIT
echo "Skyrim gamescope $VERSION installed at $ROOT"
