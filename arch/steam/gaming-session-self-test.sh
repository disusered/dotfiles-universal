#!/usr/bin/env bash

# -E so the ERR trap also reports failures raised inside the helpers below.
set -Eeuo pipefail

MODULE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROGRAM=$MODULE_DIR/gaming-session.sh
SKYRIM_LAUNCHER=$MODULE_DIR/../../games/skyrim-special-edition/skyrim-skse-launch.sh
TEST_ROOT=$(mktemp -d)

# Real podman helpers (conmon, rootlessport, aardvark-dns) outlive the podman
# process, so the stub below forks children that do too. Reap them before
# removing the tree, and drop any lock a test is still holding.
hold_lock() {
  : > "$CONTROL/lock-hold"
  rm -f -- "$CONTROL/lock-held"
  mkdir -p -- "$STATE_HOME"
  (
    exec 9>"$STATE_HOME/lock"
    flock -x 9
    : > "$CONTROL/lock-held"
    while [[ -e $CONTROL/lock-hold ]]; do sleep 0.05; done
  ) &
  lock_holder_pid=$!
  for _ in {1..200}; do
    [[ -e $CONTROL/lock-held ]] && return 0
    sleep 0.02
  done
  printf 'gaming-session self-test: external lock holder never started\n' >&2
  return 1
}

release_lock() {
  [[ -n ${lock_holder_pid:-} ]] || return 0
  rm -f -- "$CONTROL/lock-hold"
  wait "$lock_holder_pid" 2>/dev/null || true
  lock_holder_pid=
}

# The property that matters: a fresh process can still take the lock. This is
# what a descriptor leaked into a surviving child destroys.
assert_lock_free() {
  flock -x -n "$STATE_HOME/lock" -c true
}

cleanup() {
  release_lock
  if [[ -s ${CONTROL:-/dev/null}/leaked-pids ]]; then
    while read -r leaked; do
      [[ $leaked =~ ^[0-9]+$ ]] && kill -- "$leaked" 2>/dev/null || true
    done < "$CONTROL/leaked-pids"
  fi
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT
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
    # Rootless podman start leaves conmon and rootlessport running, and they
    # inherit every descriptor podman was handed. That inheritance is the
    # regression under test, so the stub must reproduce it.
    sleep 300 >/dev/null 2>&1 &
    printf '%s\n' "$!" >> "$control/leaked-pids"
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

cat > "$BIN/touch-marker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: > "${GAMING_SESSION_TEST_CONTROL:?}/marker"
EOF

cat > "$BIN/wait-for-term" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$$" > "${GAMING_SESSION_TEST_CONTROL:?}/child-pid"
trap 'exit 0' TERM
while :; do sleep 1; done
EOF

chmod +x "$BIN/systemctl" "$BIN/podman" "$BIN/assert-quiesced" "$BIN/touch-marker" "$BIN/wait-for-term"

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
# The lock must be free the instant the transaction ends. If a restored
# container's surviving helper inherited the lock descriptor, the flock outlives
# this shell and every later launch blocks before the game starts.
assert_lock_free
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

# A second transaction must be able to start straight after the first.
reset_active
timeout 10 "$PROGRAM" run --profile test -- "$BIN/assert-quiesced"
assert_lock_free
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
assert_same_lines "$CONTROL/expected-containers" "$CONTROL/active-containers"

# Ordinary play arms nothing, so it must not touch the lock at all: a held lock
# may not delay the launch even by one timeout.
reset_active
rm -f -- "$CONTROL/marker"
hold_lock
timeout 3 "$PROGRAM" run-if-armed --profile test -- "$BIN/touch-marker"
[[ -f $CONTROL/marker ]]
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
assert_same_lines "$CONTROL/expected-containers" "$CONTROL/active-containers"
[[ ! -d $STATE_HOME/active ]]
release_lock

# An armed run that cannot take the lock fails open: the game still starts,
# unquiesced, and the profile stays armed for the next attempt.
reset_active
rm -f -- "$CONTROL/marker"
"$PROGRAM" arm test >/dev/null
hold_lock
GAMING_SESSION_LOCK_TIMEOUT=1 timeout 10 "$PROGRAM" run-if-armed --profile test \
  -- "$BIN/touch-marker" 2>/dev/null
[[ -f $CONTROL/marker ]]
[[ $(<"$STATE_HOME/armed") == test ]]
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"
[[ ! -d $STATE_HOME/active ]]
release_lock
rm -f -- "$STATE_HOME/armed"

# An explicit run fails loudly instead of waiting forever.
reset_active
hold_lock
if GAMING_SESSION_LOCK_TIMEOUT=1 timeout 10 "$PROGRAM" run --profile test \
  -- /usr/bin/true >/dev/null 2>&1; then
  exit 1
fi
[[ ! -d $STATE_HOME/active ]]
assert_same_lines "$CONTROL/expected-units" "$CONTROL/active-units"

# unlock recovers a host whose lock is pinned by a process it cannot reach.
reset_active
"$PROGRAM" unlock >/dev/null
timeout 10 "$PROGRAM" run --profile test -- "$BIN/assert-quiesced"
assert_lock_free
release_lock

# unlock must refuse to drop the mutex out from under a live transaction.
mkdir -p "$STATE_HOME/active"
printf '%s\n' "$$" > "$STATE_HOME/active/owner.pid"
printf '%s\n' test > "$STATE_HOME/active/profile"
printf '%s\n' active > "$STATE_HOME/active/status"
: > "$STATE_HOME/active/units.tsv"
: > "$STATE_HOME/active/containers.tsv"
if "$PROGRAM" unlock >/dev/null 2>&1; then
  exit 1
fi
rm -rf -- "$STATE_HOME/active"

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
