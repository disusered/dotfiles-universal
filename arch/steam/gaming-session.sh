#!/usr/bin/env bash

set -uo pipefail

PROGRAM=${0##*/}
CONFIG_HOME=${GAMING_SESSION_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/gaming-session}
STATE_HOME=${GAMING_SESSION_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/gaming-session}
ACTIVE_DIR=$STATE_HOME/active
ARMED_FILE=$STATE_HOME/armed
LOCK_FILE=$STATE_HOME/lock
SYSTEMCTL=${GAMING_SESSION_SYSTEMCTL:-systemctl}
PODMAN=${GAMING_SESSION_PODMAN:-podman}

die() {
  printf '%s: %s\n' "$PROGRAM" "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage:
  $PROGRAM arm PROFILE
  $PROGRAM status
  $PROGRAM restore
  $PROGRAM run --profile PROFILE -- COMMAND [ARG...]
  $PROGRAM run-if-armed --profile PROFILE -- COMMAND [ARG...]
EOF
}

profile_file() {
  printf '%s/profiles/%s.tsv\n' "$CONFIG_HOME" "$1"
}

validate_profile_name() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || die "invalid profile name: $1"
}

with_lock() {
  mkdir -p -- "$STATE_HOME"
  exec 9>"$LOCK_FILE"
  flock -x 9
}

active_owner_alive() {
  local owner=""
  [[ -f $ACTIVE_DIR/owner.pid ]] || return 1
  read -r owner < "$ACTIVE_DIR/owner.pid" || return 1
  [[ $owner =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null
}

reverse_file() {
  local file=$1
  if command -v tac >/dev/null 2>&1; then
    tac -- "$file"
  else
    awk '{ lines[NR]=$0 } END { for (i=NR; i>=1; i--) print lines[i] }' "$file"
  fi
}

restore_active() {
  local failed=0 item
  [[ -d $ACTIVE_DIR ]] || return 0

  if [[ -s $ACTIVE_DIR/containers.tsv ]]; then
    while IFS= read -r item; do
      [[ -n $item ]] || continue
      if ! "$PODMAN" start "$item" >/dev/null; then
        printf '%s: failed to restore container %s\n' "$PROGRAM" "$item" >&2
        failed=1
      fi
    done < <(reverse_file "$ACTIVE_DIR/containers.tsv")
  fi

  if [[ -s $ACTIVE_DIR/units.tsv ]]; then
    while IFS= read -r item; do
      [[ -n $item ]] || continue
      if ! "$SYSTEMCTL" --user start "$item"; then
        printf '%s: failed to restore user unit %s\n' "$PROGRAM" "$item" >&2
        failed=1
      fi
    done < <(reverse_file "$ACTIVE_DIR/units.tsv")
  fi

  if (( failed != 0 )); then
    printf 'restore-failed\n' > "$ACTIVE_DIR/status"
    return 1
  fi

  rm -rf -- "$ACTIVE_DIR"
  return 0
}

recover_stale() {
  [[ -d $ACTIVE_DIR ]] || return 0
  if active_owner_alive; then
    die "another gaming session is active (PID $(<"$ACTIVE_DIR/owner.pid"))"
  fi
  printf '%s: restoring stale gaming-session transaction\n' "$PROGRAM" >&2
  restore_active || die "stale transaction could not be fully restored; run '$PROGRAM restore' after correcting the failure"
}

report_remaining_high_cpu() {
  local report=$ACTIVE_DIR/unmatched-high-cpu.tsv
  printf 'pid\tcpu_percent\trss_kb\tcommand\n' > "$report"
  ps -eo pid=,pcpu=,rss=,args= --sort=-pcpu | awk -v self="$$" '
    $1 != self && $2+0 >= 10 {
      pid=$1; cpu=$2; rss=$3
      $1=$2=$3=""; sub(/^[[:space:]]+/, "")
      gsub(/[\t\r\n]/, " ")
      printf "%s\t%s\t%s\t%s\n",pid,cpu,rss,$0
    }
  ' >> "$report"
  if (( $(wc -l < "$report") > 1 )); then
    printf '%s: high-CPU processes outside the allowlist remain; see %s\n' "$PROGRAM" "$report" >&2
  fi
}

begin_transaction() {
  local profile=$1 file kind name extra line_number=0
  file=$(profile_file "$profile")
  [[ -r $file ]] || die "profile not found: $file"
  command -v "$SYSTEMCTL" >/dev/null 2>&1 || die "systemctl command not found: $SYSTEMCTL"
  command -v "$PODMAN" >/dev/null 2>&1 || die "podman command not found: $PODMAN"

  mkdir -p -- "$ACTIVE_DIR"
  : > "$ACTIVE_DIR/units.tsv"
  : > "$ACTIVE_DIR/containers.tsv"
  printf '%s\n' "$profile" > "$ACTIVE_DIR/profile"
  printf '%s\n' "$$" > "$ACTIVE_DIR/owner.pid"
  printf 'stopping\n' > "$ACTIVE_DIR/status"

  while IFS=$'\t' read -r kind name extra; do
    ((line_number+=1))
    [[ -n ${kind:-} && ${kind:0:1} != '#' ]] || continue
    [[ -n ${name:-} && -z ${extra:-} ]] \
      || die "$file:$line_number must contain exactly TYPE<TAB>NAME"
    case $kind in
      unit)
        if "$SYSTEMCTL" --user is-active --quiet "$name"; then
          printf '%s\n' "$name" >> "$ACTIVE_DIR/units.tsv"
          "$SYSTEMCTL" --user stop "$name" \
            || { restore_active; die "failed to stop user unit $name"; }
        fi
        ;;
      container)
        if [[ $("$PODMAN" inspect --format '{{.State.Running}}' "$name" 2>/dev/null || true) == true ]]; then
          printf '%s\n' "$name" >> "$ACTIVE_DIR/containers.tsv"
          "$PODMAN" stop --time 30 "$name" >/dev/null \
            || { restore_active; die "failed to stop container $name"; }
        fi
        ;;
      *)
        restore_active || true
        die "$file:$line_number has unknown entry type: $kind"
        ;;
    esac
  done < "$file"

  report_remaining_high_cpu
  printf 'active\n' > "$ACTIVE_DIR/status"
}

parse_run() {
  local mode=$1
  shift
  local profile=""
  [[ ${1:-} == --profile && -n ${2:-} ]] || die "$mode requires --profile PROFILE"
  profile=$2
  shift 2
  [[ ${1:-} == -- ]] || die "$mode requires -- before the command"
  shift
  (( $# > 0 )) || die "$mode requires a command"
  validate_profile_name "$profile"

  with_lock
  recover_stale

  if [[ $mode == run-if-armed ]]; then
    local armed=""
    if [[ -f $ARMED_FILE ]]; then
      read -r armed < "$ARMED_FILE" || true
    fi
    if [[ $armed != "$profile" ]]; then
      exec 9>&-
      exec "$@"
    fi
    rm -f -- "$ARMED_FILE"
  fi

  begin_transaction "$profile"
  exec 9>&-

  local restored=0 command_status=0 command_pid=0
  # Called indirectly by the EXIT trap.
  # shellcheck disable=SC2329
  restore_on_exit() {
    local status=$?
    if (( restored == 0 )); then
      with_lock
      if restore_active; then
        restored=1
      else
        status=1
      fi
      exec 9>&-
    fi
    return "$status"
  }
  # Called indirectly by signal traps.
  # shellcheck disable=SC2329
  forward_signal() {
    local signal=$1 status=$2
    if (( command_pid > 0 )); then
      kill -s "$signal" "$command_pid" 2>/dev/null || true
      wait "$command_pid" 2>/dev/null || true
    fi
    exit "$status"
  }
  trap restore_on_exit EXIT
  trap 'forward_signal HUP 129' HUP
  trap 'forward_signal INT 130' INT
  trap 'forward_signal TERM 143' TERM

  "$@" &
  command_pid=$!
  wait "$command_pid" || command_status=$?
  exit "$command_status"
}

command=${1:-}
[[ -n $command ]] || { usage >&2; exit 2; }
shift

case $command in
  arm)
    (( $# == 1 )) || die "arm requires exactly one profile"
    validate_profile_name "$1"
    [[ -r $(profile_file "$1") ]] || die "profile not found: $(profile_file "$1")"
    with_lock
    [[ ! -d $ACTIVE_DIR ]] || die "cannot arm while a transaction exists"
    printf '%s\n' "$1" > "$ARMED_FILE"
    printf 'ARMED=%s\n' "$1"
    ;;
  status)
    (( $# == 0 )) || die "status takes no arguments"
    if [[ -f $ARMED_FILE ]]; then
      read -r armed < "$ARMED_FILE" || armed=none
      printf 'ARMED=%s\n' "${armed:-none}"
    else
      printf 'ARMED=none\n'
    fi
    if [[ -d $ACTIVE_DIR ]]; then
      printf 'TRANSACTION=%s\n' "$(<"$ACTIVE_DIR/status")"
      printf 'PROFILE=%s\n' "$(<"$ACTIVE_DIR/profile")"
      printf 'OWNER_PID=%s\n' "$(<"$ACTIVE_DIR/owner.pid")"
      printf 'UNITS=%s\n' "$(wc -l < "$ACTIVE_DIR/units.tsv")"
      printf 'CONTAINERS=%s\n' "$(wc -l < "$ACTIVE_DIR/containers.tsv")"
    else
      printf 'TRANSACTION=none\n'
    fi
    ;;
  restore)
    (( $# == 0 )) || die "restore takes no arguments"
    with_lock
    [[ -d $ACTIVE_DIR ]] || { printf 'RESTORED=none\n'; exit 0; }
    active_owner_alive && die "cannot restore while session PID $(<"$ACTIVE_DIR/owner.pid") is active"
    restore_active || die "transaction could not be fully restored"
    printf 'RESTORED=complete\n'
    ;;
  run|run-if-armed)
    parse_run "$command" "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    die "unknown command: $command"
    ;;
esac
