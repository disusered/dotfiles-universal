#!/usr/bin/env bash

# Usage: ./bruno-pick-one.sh path/to/openapi.yaml /path/to/existing/bruno/collection
# Tip: set MODE=postman if you're importing a Postman JSON instead of OpenAPI.
set -euo pipefail

SPEC="${1:?spec path required}"
DEST_ROOT="${2:?destination bruno collection folder required}"
MODE="${MODE:-openapi}" # or: postman

command -v bru >/dev/null || {
  echo "need: bru"
  exit 1
}
command -v fd >/dev/null || {
  echo "need: fd"
  exit 1
}
command -v fzf >/dev/null || {
  echo "need: fzf"
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1) Import spec -> temp
bru import "$MODE" --source "$SPEC" --output "$TMP" --collection-name "tmp" >/dev/null

# 2) Assume a single generated collection folder under $TMP
SRC_ROOT="$(fd . "$TMP" -td -d 1 | head -n1)"
[ -n "${SRC_ROOT:-}" ] || {
  echo "no generated collection"
  exit 1
}

# 3) Pick ONE file/folder to copy (skip env/metadata)
cd "$SRC_ROOT"
PICK="$(fd . . -H -t f -t d \
  -E environments -E .git -E .DS_Store -E bruno.json -E .env |
  fzf --prompt='pick one to copy > ')"
[ -n "${PICK:-}" ] || {
  echo "nothing selected"
  exit 0
}

SRC="$SRC_ROOT/$PICK"
DST="$DEST_ROOT/$PICK"

# 4) Copy (replace folder entirely; files just overwrite)
if [ -d "$SRC" ]; then
  rm -rf "$DST"
  mkdir -p "$(dirname "$DST")"
  cp -R "$SRC" "$DST"
else
  mkdir -p "$(dirname "$DST")"
  cp "$SRC" "$DST"
fi

echo "Copied: $PICK"
