#!/usr/bin/env sh
set -eu

module_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -r "$test_root"' EXIT HUP INT TERM

export POLYCHROME_NEORG_MODULE_ROOT="$module_root"
export POLYCHROME_NEORG_TEST_ROOT="$test_root"
export XDG_CACHE_HOME="$test_root/xdg/cache"
export XDG_DATA_HOME="$test_root/xdg/data"
export XDG_STATE_HOME="$test_root/xdg/state"

nvim --headless --clean -i NONE \
  -u "$module_root/tests/minimal_init.lua" \
  -l "$module_root/tests/capture_spec.lua"

if [ -n "${POLYCHROME_NEORG_SEED_ENTRY:-}" ]; then
  nvim --headless --clean -i NONE \
    -u "$module_root/tests/minimal_init.lua" \
    -l "$module_root/tests/seed_import_spec.lua"
fi
