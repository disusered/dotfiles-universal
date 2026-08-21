#!/usr/bin/env bash

set -euo pipefail

MODULE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROGRAM=$MODULE_DIR/gaming-session.sh
SKYRIM_LAUNCHER=$MODULE_DIR/../../games/skyrim-special-edition/skyrim-skse-launch.sh
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
trap 'printf "gaming-session self-test: line %s failed: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

CONFIG_HOME=$TEST_ROOT/config
STATE_HOME=$TEST_ROOT/state
CONTROL=$TEST_ROOT/control
BIN=$TEST_ROOT/bin
mkdir -p "$CONFIG_HOME/profiles" "$CONTROL" "$BIN"

cat > "$CONFIG_HOME/profiles/test.tsv" <<'EOF'
unit	unit-a.service
unit	unit-b.service
unit	unit-inactive.service
container	container-a
container	container-b
container	container-inactive
EOF

cat > "$BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
control=${GAMING_SESSION_TEST_CONTROL:?}
[[ ${1:-} == --user ]] || exit 2
shift
case ${1:-} in
  is-active)
    [[ ${2:-} == --quiet ]]
    grep -Fxq -- "${3:?}" "$control/active-units"
    ;;
  stop)
    name=${2:?}
    printf 'stop unit %s\n' "$name" >> "$control/events"
    [[ ! -f $control/fail-unit || $(<"$control/fail-unit") != "$name" ]] || exit 1
    grep -Fxv -- "$name" "$control/active-units" > "$control/active-units.next" || true
    mv -- "$control/active-units.next" "$control/active-units"
    ;;
  start)
    name=${2:?}
    printf 'start unit %s\n' "$name" >> "$control/events"
    grep -Fxq -- "$name" "$control/active-units" || printf '%s\n' "$name" >> "$control/active-units"
    ;;
  *) exit 2 ;;
esac
EOF

cat > "$BIN/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
control=${GAMING_SESSION_TEST_CONTROL:?}
case ${1:-} in
  inspect)
    [[ ${2:-} == --format ]]
    if grep -Fxq -- "${4:?}" "$control/active-containers"; then
      printf 'true\n'
    else
      printf 'false\n'
    fi
    ;;
  stop)
    [[ ${2:-} == --time && ${3:-} == 30 ]]
    name=${4:?}
    printf 'stop container %s\n' "$name" >> "$control/events"
    grep -Fxv -- "$name" "$control/active-containers" > "$control/active-containers.next" || true
    mv -- "$control/active-containers.next" "$control/active-containers"
    ;;
  start)
    name=${2:?}
    printf 'start container %s\n' "$name" >> "$control/events"
    grep -Fxq -- "$name" "$control/active-containers" || printf '%s\n' "$name" >> "$control/active-containers"
    ;;
  *) exit 2 ;;
esac
EOF

cat > "$BIN/assert-quiesced" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
control=${GAMING_SESSION_TEST_CONTROL:?}
[[ ! -s $control/active-units ]]
[[ ! -s $control/active-containers ]]
EOF

cat > "$BIN/wait-for-term" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$$" > "${GAMING_SESSION_TEST_CONTROL:?}/child-pid"
trap 'exit 0' TERM
while :; do sleep 1; done
EOF

chmod +x "$BIN/systemctl" "$BIN/podman" "$BIN/assert-quiesced" "$BIN/wait-for-term"

export GAMING_SESSION_CONFIG_HOME=$CONFIG_HOME
export GAMING_SESSION_STATE_HOME=$STATE_HOME
export GAMING_SESSION_SYSTEMCTL=$BIN/systemctl
export GAMING_SESSION_PODMAN=$BIN/podman
export GAMING_SESSION_TEST_CONTROL=$CONTROL

reset_active() {
  printf '%s\n' unit-a.service unit-b.service > "$CONTROL/active-units"
  printf '%s\n' container-a container-b > "$CONTROL/active-containers"
  : > "$CONTROL/events"
}

assert_same_lines() {
  cmp -s <(sort -- "$1") <(sort -- "$2")
}

reset_active
[[ $($PROGRAM status) == $'ARMED=none\nTRANSACTION=none' ]]
$PROGRAM arm test >/dev/null
[[ $($PROGRAM status) == $'ARMED=test\nTRANSACTION=none' ]]
$PROGRAM run-if-armed --profile test -- "$BIN/assert-quiesced"
[[ $($PROGRAM status) == $'ARMED=none\nTRANSACTION=none' ]]

printf '%s\n' \
  'stop unit unit-a.service' \
  'stop unit unit-b.service' \
  'stop container container-a' \
  'stop container container-b' \
  'start container container-b' \
  'start container container-a' \
  'start unit unit-b.service' \
  'start unit unit-a.service' \
  > "$CONTROL/expected-events"
cmp -s "$CONTROL/expected-events" "$CONTROL/events"
printf '%s\n' unit-a.service unit-b.service > "$CONTROL/expected-units"
printf '%s\n' container-a container-b > "$CONTROL/expected-containers"
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
assert_same_lines "$CONTROL/expected-containers" "$CONTROL/active-containers"

reset_active
if $PROGRAM run --profile test -- /usr/bin/false; then
  exit 1
fi
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
assert_same_lines "$CONTROL/expected-containers" "$CONTROL/active-containers"
[[ ! -d $STATE_HOME/active ]]

reset_active
printf '%s\n' unit-b.service > "$CONTROL/fail-unit"
if $PROGRAM run --profile test -- /usr/bin/true >/dev/null 2>&1; then
  exit 1
fi
rm -- "$CONTROL/fail-unit"
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
assert_same_lines "$CONTROL/expected-containers" "$CONTROL/active-containers"
[[ ! -d $STATE_HOME/active ]]

reset_active
$PROGRAM run --profile test -- "$BIN/wait-for-term" &
session_pid=$!
for _ in {1..100}; do
  [[ -s $CONTROL/child-pid && -f $STATE_HOME/active/status && $(<"$STATE_HOME/active/status") == active ]] && break
  sleep 0.02
done
[[ -s $CONTROL/child-pid ]]
child_pid=$(<"$CONTROL/child-pid")
kill -TERM "$session_pid"
if wait "$session_pid"; then
  exit 1
else
  status=$?
fi
[[ $status == 143 ]]
[[ ! -e /proc/$child_pid ]]
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
assert_same_lines "$CONTROL/expected-containers" "$CONTROL/active-containers"
[[ ! -d $STATE_HOME/active ]]

reset_active
mkdir -p "$STATE_HOME/active"
printf '%s\n' 99999999 > "$STATE_HOME/active/owner.pid"
printf '%s\n' test > "$STATE_HOME/active/profile"
printf '%s\n' active > "$STATE_HOME/active/status"
: > "$STATE_HOME/active/units.tsv"
: > "$STATE_HOME/active/containers.tsv"
$PROGRAM run --profile test -- "$BIN/assert-quiesced"
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
assert_same_lines "$CONTROL/expected-containers" "$CONTROL/active-containers"
[[ ! -d $STATE_HOME/active ]]

mkdir -p "$TEST_ROOT/home/.local/bin" "$TEST_ROOT/game"
touch "$TEST_ROOT/game/SkyrimSELauncher.exe" "$TEST_ROOT/game/skse64_loader.exe"
cat > "$TEST_ROOT/home/.local/bin/gaming-session" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${GAMING_SESSION_TEST_CONTROL:?}/launcher-args"
EOF
chmod +x "$TEST_ROOT/home/.local/bin/gaming-session"

HOME=$TEST_ROOT/home "$SKYRIM_LAUNCHER" "$TEST_ROOT/game/SkyrimSELauncher.exe" --fixture
printf '%s\n' run-if-armed --profile co-located -- "$TEST_ROOT/game/skse64_loader.exe" --fixture \
  > "$CONTROL/expected-launcher-args"
cmp -s "$CONTROL/expected-launcher-args" "$CONTROL/launcher-args"

HOME=$TEST_ROOT/home SKYRIM_HOST_WORKLOAD_POLICY=quiesced \
  "$SKYRIM_LAUNCHER" "$TEST_ROOT/game/SkyrimSELauncher.exe" --fixture
printf '%s\n' run --profile co-located -- "$TEST_ROOT/game/skse64_loader.exe" --fixture \
  > "$CONTROL/expected-launcher-args"
cmp -s "$CONTROL/expected-launcher-args" "$CONTROL/launcher-args"

if HOME=$TEST_ROOT/home SKYRIM_HOST_WORKLOAD_POLICY=invalid \
  "$SKYRIM_LAUNCHER" "$TEST_ROOT/game/SkyrimSELauncher.exe" >/dev/null 2>&1; then
  exit 1
fi

printf 'gaming-session self-test: PASS\n'
