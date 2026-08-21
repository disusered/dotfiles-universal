#!/usr/bin/env bash
# Guards the contract of skyrim-skse-launch.sh: swap Steam's registered
# executable for the SKSE loader, exec it directly, and never block the launch.
#
# The last assertion is the important one. This wrapper used to route every
# launch through a host-quiescing helper that took a session lock, and a leaked
# file descriptor left that lock held, so the wrapper blocked before Proton
# started and the game simply never appeared. Quiescing is now an explicit
# `cfg dev off`, and nothing in the play path may reintroduce a dependency on it.

# -E so the ERR trap also reports failures raised inside functions.
set -Eeuo pipefail

MODULE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LAUNCHER=$MODULE_DIR/skyrim-skse-launch.sh
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
trap 'printf "skyrim-skse-launch self-test: line %s failed: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

GAME=$TEST_ROOT/game
BIN=$TEST_ROOT/home/.local/bin
mkdir -p "$GAME" "$BIN"

# Records its own arguments so the test can prove what was actually executed.
cat > "$GAME/skse64_loader.exe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_RECORD/loader-args"
EOF
chmod +x "$GAME/skse64_loader.exe"
touch "$GAME/SkyrimSELauncher.exe"

# Any wrapper the launcher might reach for. Reaching for one is the regression.
for helper in gaming-session cfg; do
  cat > "$BIN/$helper" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$helper" "\$*" >> "\$TEST_RECORD/helper-called"
EOF
  chmod +x "$BIN/$helper"
done

export TEST_RECORD=$TEST_ROOT

# Steam registers SkyrimSELauncher.exe, not SkyrimSE.exe. Matching only the
# latter meant the shim never fired, SKSE never loaded, and Engine Fixes'
# preloader patched a process with no SKSE behind it.
HOME=$TEST_ROOT/home PATH="$BIN:$PATH" \
  "$LAUNCHER" "$GAME/SkyrimSELauncher.exe" --fixture
printf '%s\n' --fixture > "$TEST_ROOT/expected-loader-args"
cmp -s "$TEST_ROOT/expected-loader-args" "$TEST_ROOT/loader-args"
[[ ! -e $TEST_ROOT/helper-called ]]

# Wine is case-insensitive and Steam's casing has changed before.
rm -f -- "$TEST_ROOT/loader-args"
cp -- "$GAME/SkyrimSELauncher.exe" "$GAME/skyrimselauncher.EXE"
HOME=$TEST_ROOT/home PATH="$BIN:$PATH" \
  "$LAUNCHER" "$GAME/skyrimselauncher.EXE" --fixture
cmp -s "$TEST_ROOT/expected-loader-args" "$TEST_ROOT/loader-args"

# No loader present: the game must still start, vanilla, rather than fail.
BARE=$TEST_ROOT/bare
mkdir -p "$BARE"
cat > "$BARE/SkyrimSELauncher.exe" <<'EOF'
#!/usr/bin/env bash
printf 'vanilla %s\n' "$@" > "$TEST_RECORD/vanilla-args"
EOF
chmod +x "$BARE/SkyrimSELauncher.exe"
HOME=$TEST_ROOT/home PATH="$BIN:$PATH" \
  "$LAUNCHER" "$BARE/SkyrimSELauncher.exe" --fixture
[[ $(<"$TEST_ROOT/vanilla-args") == 'vanilla --fixture' ]]

# A command with no Skyrim executable passes through untouched.
rm -f -- "$TEST_ROOT/loader-args"
HOME=$TEST_ROOT/home PATH="$BIN:$PATH" \
  "$LAUNCHER" "$GAME/skse64_loader.exe" --passthrough
printf '%s\n' --passthrough > "$TEST_ROOT/expected-loader-args"
cmp -s "$TEST_ROOT/expected-loader-args" "$TEST_ROOT/loader-args"
[[ ! -e $TEST_ROOT/helper-called ]]

printf 'skyrim-skse-launch self-test: PASS\n'
