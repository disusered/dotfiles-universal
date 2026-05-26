#!/usr/bin/env sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)

DOTFILES_DIR="$repo" CFG_DIR="$repo/cfg" cfg update kitty-diff --dry-run >/dev/null

for pattern in \
  'kitty-diff' \
  'tools/kitty/diff.conf'
do
  DOTFILES_DIR="$repo" CFG_DIR="$repo/cfg" cfg update kitty-diff --dry-run | grep -F -- "$pattern" >/dev/null
done

test -f "$repo/tools/kitty/diff.conf.tera"
grep -F -- "color_scheme dark" "$repo/tools/kitty/diff.conf.tera" >/dev/null
grep -F -- "dark_removed_bg #{{ red | blend(base=base, amount=10) | hex }}" "$repo/tools/kitty/diff.conf.tera" >/dev/null
grep -F -- "dark_added_bg #{{ green | blend(base=base, amount=10) | hex }}" "$repo/tools/kitty/diff.conf.tera" >/dev/null
