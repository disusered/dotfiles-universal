#!/usr/bin/env bash
# Queue, verify, and record controlled Skyrim benchmark runs.

set -euo pipefail

APP_ID=489830
SCRIPT_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
MODULE_DIR=$(dirname -- "$SCRIPT_PATH")
MATRIX_FILE=${SKYRIM_BENCHMARK_MATRIX:-$MODULE_DIR/benchmark/matrix.tsv}
PROFILES_FILE=${SKYRIM_BENCHMARK_PROFILES:-$MODULE_DIR/benchmark/profiles.tsv}
PRESENTATION_MATRIX_FILE=${SKYRIM_BENCHMARK_PRESENTATION_MATRIX:-$MODULE_DIR/benchmark/presentation-matrix.tsv}
PRESENTATION_PROFILES_FILE=${SKYRIM_BENCHMARK_PRESENTATION_PROFILES:-$MODULE_DIR/benchmark/presentation-profiles.tsv}
STATE_DIR=${SKYRIM_PERF_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/skyrim-performance}
RUNS_DIR=$STATE_DIR/runs
ARMED_FILE=$STATE_DIR/armed-run
ACTIVE_FILE=$STATE_DIR/active-run
BOOT_ID_FILE=${SKYRIM_BENCHMARK_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}
MANGOHUD_CONFIG_FILE=${SKYRIM_BENCHMARK_MANGOHUD_CONFIG:-$HOME/.config/MangoHud/skyrim-benchmark.conf}
PREFS_INI_OVERRIDE=${SKYRIM_BENCHMARK_PREFS_INI:-}
SKYRIM_INI_OVERRIDE=${SKYRIM_BENCHMARK_SKYRIM_INI:-}
TRACE_NOMINAL_INTERVAL=0.25
TRACE_MAX_GAP=2.0
TRACE_MIN_DENSITY=2.0

# Populated by load_profile/load_prepared and shared by the command handlers.
PROFILE=""
GAME_WIDTH=""
GAME_HEIGHT=""
OUTPUT_WIDTH=""
OUTPUT_HEIGHT=""
EXPLICIT_NESTED=""
SCALER=""
FILTER=""
CONNECTOR=""
PROFILE_CONNECTOR=""
REFRESH_HZ=""
RUN_ID=""
ROUTE=""
WARMUP_SECONDS=""
DURATION_SECONDS=""
STEAM_BUILD_ID=""
CONFIG_HASH=""
RUN_KIND="legacy"
RUN_MATRIX_FILE=""
BOOT_ID_AT_QUEUE=""
CLEAN_BOOT="false"
REPETITION=""
PRESENTATION_PROFILE=""
DISPLAY_PROFILE=""
GAMESCOPE_SOURCE=""
GAMESCOPE_MODE="enabled"
GAMESCOPE_BIN=""
GAMESCOPE_BIN_DIR=""
GAMESCOPE_SCRIPT_PATH=""
GAMESCOPE_BIN_HASH=""
GAMESCOPE_REAPER_HASH=""
GAMESCOPE_VERSION=""
GAMESCOPE_ARGS=""
GAMESCOPE_BACKEND=""
OVERLAY_POLICY=""
HYPR_VFR=""
HYPR_ALLOW_TEARING=""
HYPR_IMMEDIATE=""
HYPR_VFR_AT_QUEUE=""
HYPR_ALLOW_TEARING_AT_QUEUE=""
FPS_CAP=""
TRACE_STATUS_FILE=""
HYPR_VERSION_HASH=""
HYPR_VERSION_JSON=""
KERNEL_RELEASE=""
MONITOR_TOPOLOGY_HASH=""
PREFS_INI_HASH=""
SKYRIM_INI_HASH=""

CONFIG_PATHS=(
  "$SCRIPT_PATH"
  "$MODULE_DIR/scopebuddy.conf"
  "$MODULE_DIR/SkyrimPrefs.igpu.ini"
  "$MODULE_DIR/Skyrim.ini"
  "$MODULE_DIR/mangohud-benchmark.conf"
  "$MODULE_DIR/mods/config/data/SKSE/Plugins/SSEDisplayTweaks.ini"
  "$MODULE_DIR/mods/manifest.tsv"
  "$PROFILES_FILE"
)

PRESENTATION_CONFIG_PATHS=(
  "$PRESENTATION_PROFILES_FILE"
  "$MODULE_DIR/skyrim.conf"
  "$MODULE_DIR/skyrim-skse-launch.sh"
  "$MODULE_DIR/../hotline-miami/hotline-miami.conf"
  "$MODULE_DIR/../planescape-torment-ee/planescape.conf"
  "$MODULE_DIR/../three-kingdoms/three-kingdoms.conf"
  "$MODULE_DIR/../../arch/steam/steam.conf"
  "$MODULE_DIR/../../tools/scopebuddy/scb.conf"
  "$MODULE_DIR/../../arch/hyprland/hyprland.conf.tera"
)

usage() {
  cat <<'EOF'
Usage:
  skyrim-benchmark queue RUN_ID
  skyrim-benchmark status
  skyrim-benchmark profile PROFILE
  skyrim-benchmark complete RUN_ID --cursor good|bad --verdict accepted|rejected|inconclusive --notes TEXT
  skyrim-benchmark complete RUN_ID --game-cursor good|bad|not-tested --desktop-cursor good|bad|not-tested --verdict accepted|rejected|inconclusive --notes TEXT
  skyrim-benchmark mark stall-recovered [--scope game|desktop]
  skyrim-benchmark invalidate RUN_ID REASON
  skyrim-benchmark cancel

Queue creates a persistent, instrumented run from the FPS or presentation
matrix. A run is ready only when `status` prints STATE=READY.
EOF
}

die() {
  echo "skyrim-benchmark: $*" >&2
  exit 1
}

require_file() {
  [[ -f $1 ]] || die "required file missing: $1"
}

sanitize_cell() {
  local value=$1
  value=${value//$'\t'/ }
  value=${value//$'\n'/ }
  value=${value//$'\r'/ }
  printf '%s' "$value"
}

tsv_column() {
  local file=$1 name=$2
  awk -F '\t' -v name="$name" '
    NR == 1 {
      for (i=1; i<=NF; i++) if ($i == name) { print i; exit }
      exit 3
    }
  ' "$file"
}

tsv_field() {
  local file=$1 key=$2 column=$3 key_column=${4:-run_id}
  local key_index value_index
  key_index=$(tsv_column "$file" "$key_column") || die "missing $key_column column in $file"
  value_index=$(tsv_column "$file" "$column") || die "missing $column column in $file"
  awk -F '\t' -v key="$key" -v ki="$key_index" -v vi="$value_index" '
    NR > 1 && $ki == key { print $vi; found=1; exit }
    END { if (!found) exit 3 }
  ' "$file"
}

tsv_has_key() {
  local file=$1 key=$2 key_column=${3:-run_id}
  [[ -f $file ]] || return 1
  local key_index
  key_index=$(tsv_column "$file" "$key_column") || return 1
  awk -F '\t' -v key="$key" -v ki="$key_index" '
    NR > 1 && $ki == key { found=1; exit }
    END { exit !found }
  ' "$file"
}

update_tsv_cells() {
  local file=$1 key=$2
  shift 2
  (( $# > 0 && $# % 2 == 0 )) || die "update_tsv_cells requires column/value pairs"
  local assignments="" column index value tmp
  while (( $# > 0 )); do
    column=$1
    value=$2
    shift 2
    index=$(tsv_column "$file" "$column") || die "missing $column column in $file"
    value=$(sanitize_cell "$value")
    assignments+="${assignments:+$'\036'}$index"$'\037'"$value"
  done
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  if ! awk -F '\t' -v OFS='\t' -v key="$key" -v assignments="$assignments" '
    BEGIN {
      count=split(assignments, pairs, "\036")
      for (i=1; i<=count; i++) {
        pos=index(pairs[i], "\037")
        columns[i]=substr(pairs[i], 1, pos-1)
        values[i]=substr(pairs[i], pos+1)
      }
    }
    NR > 1 && $1 == key {
      for (i=1; i<=count; i++) $columns[i]=values[i]
      found=1
    }
    { print }
    END { if (!found) exit 3 }
  ' "$file" > "$tmp"; then
    rm -f -- "$tmp"
    die "run not found in matrix: $key"
  fi
  mv -- "$tmp" "$file"
}

locate_run() {
  local run_id=$1 in_presentation=0 in_legacy=0
  tsv_has_key "$PRESENTATION_MATRIX_FILE" "$run_id" && in_presentation=1
  matrix_has_run "$run_id" && in_legacy=1
  (( in_presentation + in_legacy == 1 )) \
    || { (( in_presentation + in_legacy == 0 )) && die "run not found in either matrix: $run_id"; \
         die "run ID is ambiguous across matrices: $run_id"; }
  if (( in_presentation )); then
    RUN_KIND=presentation
    RUN_MATRIX_FILE=$PRESENTATION_MATRIX_FILE
  else
    RUN_KIND=legacy
    RUN_MATRIX_FILE=$MATRIX_FILE
  fi
}

run_field() {
  local run_id=$1 column=$2 legacy_column=${3:-}
  if [[ $RUN_KIND == presentation ]]; then
    tsv_field "$RUN_MATRIX_FILE" "$run_id" "$column"
  else
    [[ -n $legacy_column ]] || die "$column is unavailable for legacy run $run_id"
    matrix_field "$run_id" "$legacy_column"
  fi
}

matrix_field() {
  local run_id=$1 column=$2
  awk -F '\t' -v run_id="$run_id" -v column="$column" '
    NR > 1 && $1 == run_id { print $column; found=1; exit }
    END { if (!found) exit 3 }
  ' "$MATRIX_FILE"
}

matrix_has_run() {
  local run_id=$1
  awk -F '\t' -v run_id="$run_id" 'NR > 1 && $1 == run_id { found=1 } END { exit !found }' "$MATRIX_FILE"
}

update_matrix_status() {
  local run_id=$1 status=$2
  local tmp
  tmp=$(mktemp "${MATRIX_FILE}.tmp.XXXXXX")
  if ! awk -F '\t' -v OFS='\t' -v run_id="$run_id" -v status="$status" '
    $1 == run_id { $2=status; found=1 }
    { print }
    END { if (!found) exit 3 }
  ' "$MATRIX_FILE" > "$tmp"; then
    rm -f -- "$tmp"
    die "run not found in matrix: $run_id"
  fi
  mv -- "$tmp" "$MATRIX_FILE"
}

update_run_status() {
  local run_id=$1 status=$2
  if [[ $RUN_KIND == presentation ]]; then
    update_tsv_cells "$PRESENTATION_MATRIX_FILE" "$run_id" status "$status"
  else
    update_matrix_status "$run_id" "$status"
  fi
}

complete_matrix_row() {
  local run_id=$1 instrumentation=$2 cursor=$3 avg=$4 p1=$5 p01=$6 verdict=$7 notes=$8
  local tmp
  tmp=$(mktemp "${MATRIX_FILE}.tmp.XXXXXX")
  if ! awk -F '\t' -v OFS='\t' \
    -v run_id="$run_id" -v instrumentation="$instrumentation" \
    -v cursor="$cursor" -v avg="$avg" -v p1="$p1" -v p01="$p01" \
    -v verdict="$verdict" -v notes="$notes" '
      $1 == run_id {
        $2="completed"; $11=instrumentation; $12=cursor; $13=avg;
        $14=p1; $15=p01; $16=verdict; $17=notes; found=1
      }
      { print }
      END { if (!found) exit 3 }
    ' "$MATRIX_FILE" > "$tmp"; then
    rm -f -- "$tmp"
    die "run not found in matrix: $run_id"
  fi
  mv -- "$tmp" "$MATRIX_FILE"
}

complete_presentation_row() {
  local run_id=$1 instrumentation=$2 game_cursor=$3 desktop_cursor=$4 stalls=$5
  local avg=$6 p1=$7 p01=$8 verdict=$9 notes=${10}
  update_tsv_cells "$PRESENTATION_MATRIX_FILE" "$run_id" \
    status completed instrumentation "$instrumentation" game_cursor "$game_cursor" \
    desktop_cursor "$desktop_cursor" stall_count "$stalls" avg_fps "$avg" \
    p1_fps "$p1" p01_fps "$p01" verdict "$verdict" notes "$notes"
}

promote_direct_replicate() {
  local completed=$1 run_id status baseline factor
  # The loop reads the original inode while each promotion atomically replaces the file.
  # shellcheck disable=SC2094
  while IFS=$'\t' read -r run_id status baseline _ factor _; do
    [[ $run_id == run_id ]] && continue
    if [[ $status == conditional && $baseline == "$completed" && $factor == replicate ]]; then
      update_tsv_cells "$PRESENTATION_MATRIX_FILE" "$run_id" status planned
    fi
  done < "$PRESENTATION_MATRIX_FILE"
}

load_profile() {
  local requested=$1 row
  row=$(awk -F '\t' -v profile="$requested" '
    NR > 1 && $1 == profile { print; found=1; exit }
    END { if (!found) exit 3 }
  ' "$PROFILES_FILE") || die "unknown profile: $requested"

  IFS=$'\t' read -r PROFILE GAME_WIDTH GAME_HEIGHT OUTPUT_WIDTH OUTPUT_HEIGHT \
    EXPLICIT_NESTED SCALER FILTER PROFILE_CONNECTOR REFRESH_HZ <<< "$row"

  [[ $PROFILE =~ ^[a-z0-9-]+$ ]] || die "invalid profile name: $PROFILE"
  for value in "$GAME_WIDTH" "$GAME_HEIGHT" "$OUTPUT_WIDTH" "$OUTPUT_HEIGHT" "$REFRESH_HZ"; do
    [[ $value =~ ^[0-9]+$ ]] || die "invalid numeric value in profile $PROFILE"
  done
  [[ $EXPLICIT_NESTED == 0 || $EXPLICIT_NESTED == 1 ]] || die "invalid explicit_nested in profile $PROFILE"
  [[ $SCALER =~ ^(none|fit)$ ]] || die "invalid scaler in profile $PROFILE"
  [[ $FILTER =~ ^(none|linear|fsr)$ ]] || die "invalid filter in profile $PROFILE"
  [[ $PROFILE_CONNECTOR == focused || $PROFILE_CONNECTOR =~ ^[A-Za-z0-9-]+$ ]] \
    || die "invalid connector in profile $PROFILE"
}

presentation_profile_field() {
  local requested=$1 column=$2
  tsv_field "$PRESENTATION_PROFILES_FILE" "$requested" "$column" profile
}

load_presentation_profile() {
  local requested=$1
  require_file "$PRESENTATION_PROFILES_FILE"
  tsv_has_key "$PRESENTATION_PROFILES_FILE" "$requested" profile \
    || die "unknown presentation profile: $requested"

  PRESENTATION_PROFILE=$requested
  DISPLAY_PROFILE=$(presentation_profile_field "$requested" display_profile)
  GAMESCOPE_SOURCE=$(presentation_profile_field "$requested" gamescope_source)
  GAMESCOPE_BACKEND=$(presentation_profile_field "$requested" backend)
  OVERLAY_POLICY=$(presentation_profile_field "$requested" overlay_policy)
  HYPR_VFR=$(presentation_profile_field "$requested" hypr_vfr)
  HYPR_ALLOW_TEARING=$(presentation_profile_field "$requested" hypr_allow_tearing)
  HYPR_IMMEDIATE=$(presentation_profile_field "$requested" client_immediate)
  FPS_CAP=$(presentation_profile_field "$requested" fps_cap)

  [[ $PRESENTATION_PROFILE =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || die "invalid presentation profile name: $PRESENTATION_PROFILE"
  [[ $GAMESCOPE_SOURCE == system || $GAMESCOPE_SOURCE == bypass || \
     $GAMESCOPE_SOURCE == cached-* || $GAMESCOPE_SOURCE == cached:* || \
     $GAMESCOPE_SOURCE == /* ]] \
    || die "gamescope_source must be system, bypass, cached-VERSION, cached:VERSION, or an absolute path"
  [[ $GAMESCOPE_BACKEND == wayland || $GAMESCOPE_BACKEND == sdl ]] \
    || die "backend must be wayland or sdl"
  [[ $OVERLAY_POLICY == game || $OVERLAY_POLICY == off ]] \
    || die "overlay_policy must be game or off"
  for value in "$HYPR_VFR" "$HYPR_ALLOW_TEARING" "$HYPR_IMMEDIATE"; do
    [[ $value == true || $value == false ]] || die "presentation booleans must be true or false"
  done
  [[ $FPS_CAP =~ ^[0-9]+$ ]] || die "fps_cap must be a non-negative integer"
  if [[ $GAMESCOPE_SOURCE == bypass ]]; then
    GAMESCOPE_MODE=bypass
  else
    GAMESCOPE_MODE=enabled
  fi
  load_profile "$DISPLAY_PROFILE"
}

presentation_fields() {
  printf '%s\n' display_profile gamescope_source backend overlay_policy \
    hypr_vfr hypr_allow_tearing client_immediate fps_cap
}

independent_factor_accepted() {
  local baseline=$1 factor=$2 expected=$3
  local run_id status row_baseline row_factor profile verdict value short_id soak_id
  # Nested lookups only read this matrix.
  # shellcheck disable=SC2094
  while IFS=$'\t' read -r run_id status row_baseline profile row_factor _; do
    [[ $run_id == run_id ]] && continue
    [[ $status == completed && $row_baseline == "$baseline" && $row_factor == "$factor" ]] || continue
    verdict=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" verdict) || continue
    [[ $verdict == accepted ]] || continue
    value=$(presentation_profile_field "$profile" "$factor") || continue
    [[ $value == "$expected" ]] || continue
    short_id=$(awk -F '\t' -v parent="$run_id" -v profile="$profile" '
      NR > 1 && $3 == parent && $4 == profile && $5 == "replicate" && $12 == "short-2" &&
        $2 == "completed" && $20 == "accepted" { print $1; exit }
    ' "$PRESENTATION_MATRIX_FILE")
    [[ -n $short_id ]] || continue
    soak_id=$(awk -F '\t' -v parent="$short_id" -v profile="$profile" '
      NR > 1 && $3 == parent && $4 == profile && $5 == "replicate" && $12 == "soak" &&
        $2 == "completed" && $20 == "accepted" { print $1; exit }
    ' "$PRESENTATION_MATRIX_FILE")
    [[ -n $soak_id ]] && return 0
  done < "$PRESENTATION_MATRIX_FILE"
  return 1
}

verify_one_factor() {
  local run_id=$1 baseline factor old_value new_value baseline_profile field
  local -a changed=()
  local -A candidate=() reference=()

  baseline=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" baseline)
  factor=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" factor)
  old_value=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" old_value)
  new_value=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" new_value)
  while IFS= read -r field; do
    candidate[$field]=$(presentation_profile_field "$PRESENTATION_PROFILE" "$field")
  done < <(presentation_fields)

  if [[ $baseline == none ]]; then
    [[ $factor == baseline ]] || die "$run_id has no baseline but factor is $factor"
    [[ $old_value == none ]] || die "$run_id baseline old_value must be none"
    return
  fi

  tsv_has_key "$PRESENTATION_MATRIX_FILE" "$baseline" \
    || die "$run_id names missing presentation baseline $baseline"
  baseline_profile=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$baseline" profile)
  while IFS= read -r field; do
    reference[$field]=$(presentation_profile_field "$baseline_profile" "$field")
    [[ ${candidate[$field]} == "${reference[$field]}" ]] || changed+=("$field")
  done < <(presentation_fields)

  case $factor in
    replicate|soak)
      (( ${#changed[@]} == 0 )) \
        || die "$run_id is $factor but changes: ${changed[*]}"
      [[ $old_value == "$new_value" ]] \
        || die "$run_id $factor must declare identical old/new values"
      ;;
    combine)
      (( ${#changed[@]} > 1 )) || die "$run_id combine must change at least two fields"
      for field in "${changed[@]}"; do
        independent_factor_accepted "$baseline" "$field" "${candidate[$field]}" \
          || die "$run_id combines $field=${candidate[$field]} without an accepted independent cell"
      done
      ;;
    *)
      (( ${#changed[@]} == 1 )) \
        || die "$run_id must change exactly one presentation field; changed: ${changed[*]:-none}"
      [[ ${changed[0]} == "$factor" ]] \
        || die "$run_id declares factor $factor but changes ${changed[0]}"
      [[ ${reference[$factor]} == "$old_value" ]] \
        || die "$run_id old_value=$old_value, baseline has ${reference[$factor]}"
      [[ ${candidate[$factor]} == "$new_value" ]] \
        || die "$run_id new_value=$new_value, profile has ${candidate[$factor]}"
      ;;
  esac
}

verify_repetition_predecessor() {
  local run_id=$1 baseline status verdict factor
  [[ $REPETITION != diagnostic ]] || return 0
  baseline=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" baseline)
  factor=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" factor)
  status=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$baseline" status)
  verdict=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$baseline" verdict)
  if [[ $REPETITION == short-1 && $factor == hypr_allow_tearing && $status == reference ]]; then
    return 0
  fi
  [[ $status == completed && $verdict == accepted ]] \
    || die "$run_id requires accepted predecessor $baseline"
}

accepted_tearing_reference() {
  local first second first_avg first_p1 second_avg second_p1
  first=$(awk -F '\t' '
    NR>1 && $2=="completed" && $5=="hypr_allow_tearing" && $7=="false" &&
      $12=="short-1" && $20=="accepted" {print $1; exit}
  ' "$PRESENTATION_MATRIX_FILE")
  [[ -n $first ]] || return 1
  second=$(awk -F '\t' -v parent="$first" '
    NR>1 && $2=="completed" && $3==parent && $5=="replicate" &&
      $12=="short-2" && $20=="accepted" {print $1; exit}
  ' "$PRESENTATION_MATRIX_FILE")
  [[ -n $second ]] || return 1
  first_avg=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$first" avg_fps)
  first_p1=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$first" p1_fps)
  second_avg=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$second" avg_fps)
  second_p1=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$second" p1_fps)
  for value in "$first_avg" "$first_p1" "$second_avg" "$second_p1"; do
    [[ $value =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  done
  awk -v a1="$first_avg" -v p1="$first_p1" -v a2="$second_avg" -v p2="$second_p1" \
    -v label="$first+$second" 'BEGIN {printf "%.6f\t%.6f\t%s\n",(a1+a2)/2,(p1+p2)/2,label}'
}

verify_fps_nonregression() {
  local run_id=$1 current_avg=$2 current_p1=$3 baseline repetition
  local baseline_avg baseline_p1 reference_avg reference_p1 reference_label="" factor baseline_factor=""
  local compared=false needs_controlled_reference=false
  [[ $current_avg =~ ^[0-9]+([.][0-9]+)?$ && $current_p1 =~ ^[0-9]+([.][0-9]+)?$ ]] \
    || die "$run_id has invalid MangoHud average/1% low values: $current_avg/$current_p1"
  baseline=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" baseline)
  repetition=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" repetition)
  factor=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$run_id" factor)
  if [[ $repetition == short-2 && $baseline != none ]]; then
    baseline_factor=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$baseline" factor)
  fi
  if [[ $baseline != none ]]; then
    baseline_avg=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$baseline" avg_fps)
    baseline_p1=$(tsv_field "$PRESENTATION_MATRIX_FILE" "$baseline" p1_fps)
    if [[ $baseline_avg =~ ^[0-9]+([.][0-9]+)?$ && $baseline_p1 =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      if [[ $repetition == short-2 && $baseline_factor == hypr_allow_tearing ]]; then
        compare_fps_consistency "$current_avg" "$current_p1" "$baseline_avg" "$baseline_p1" "$baseline"
      else
        compare_fps "$current_avg" "$current_p1" "$baseline_avg" "$baseline_p1" "$baseline"
      fi
      compared=true
    fi
  fi

  if [[ $repetition == short-1 && $factor != hypr_allow_tearing ]]; then
    needs_controlled_reference=true
  elif [[ $repetition == short-2 ]]; then
    [[ $baseline_factor != hypr_allow_tearing ]] && needs_controlled_reference=true
  fi
  if [[ $needs_controlled_reference == true ]]; then
    read -r reference_avg reference_p1 reference_label < <(accepted_tearing_reference) \
      || die "$run_id has no accepted H1 short-1/short-2 controlled FPS reference"
    compare_fps "$current_avg" "$current_p1" "$reference_avg" "$reference_p1" "$reference_label"
    compared=true
  fi
  if [[ $compared != true && $factor != hypr_allow_tearing ]]; then
    die "$run_id has no accepted controlled FPS reference"
  fi
}

compare_fps_consistency() {
  local current_avg=$1 current_p1=$2 baseline_avg=$3 baseline_p1=$4 label=$5
  awk -v current="$current_avg" -v baseline="$baseline_avg" 'BEGIN {
    denominator=current+baseline
    difference=(current>baseline ? current-baseline : baseline-current)
    exit !(denominator>0 && (2*difference/denominator)<=0.05)
  }' || die "average FPS $current_avg differs symmetrically by more than 5% from $baseline_avg in $label"
  awk -v current="$current_p1" -v baseline="$baseline_p1" 'BEGIN {
    denominator=current+baseline
    difference=(current>baseline ? current-baseline : baseline-current)
    exit !(denominator>0 && (2*difference/denominator)<=0.05)
  }' || die "1% low $current_p1 differs symmetrically by more than 5% from $baseline_p1 in $label"
}

compare_fps() {
  local current_avg=$1 current_p1=$2 baseline_avg=$3 baseline_p1=$4 label=$5
  awk -v current="$current_avg" -v baseline="$baseline_avg" \
    'BEGIN {exit !(current >= baseline*0.95)}' \
    || die "average FPS $current_avg regressed more than 5% from $baseline_avg in $label"
  awk -v current="$current_p1" -v baseline="$baseline_p1" \
    'BEGIN {exit !(current >= baseline*0.95)}' \
    || die "1% low $current_p1 regressed more than 5% from $baseline_p1 in $label"
}

profile_args() {
  local args=""
  if [[ $EXPLICIT_NESTED == 1 ]]; then
    args="-w $GAME_WIDTH -h $GAME_HEIGHT -S $SCALER -F $FILTER"
  fi
  printf '%s' "$args"
}

print_profile() {
  load_profile "$1"
  printf 'PROFILE=%s\n' "$PROFILE"
  printf 'GAME=%sx%s\n' "$GAME_WIDTH" "$GAME_HEIGHT"
  if [[ $EXPLICIT_NESTED == 1 ]]; then
    printf 'NESTED=%sx%s\n' "$GAME_WIDTH" "$GAME_HEIGHT"
  else
    printf 'NESTED=output-default\n'
  fi
  printf 'OUTPUT=%sx%s@%s %s\n' "$OUTPUT_WIDTH" "$OUTPUT_HEIGHT" "$REFRESH_HZ" "$PROFILE_CONNECTOR"
  printf 'SCALER=%s\n' "$SCALER"
  printf 'FILTER=%s\n' "$FILTER"
  printf 'GAMESCOPE_PROFILE_ARGS=%s\n' "$(profile_args)"
}

config_hashes() {
  local path
  for path in "${CONFIG_PATHS[@]}"; do
    require_file "$path"
    sha256sum -- "$path"
  done
  if [[ $RUN_KIND == presentation ]]; then
    for path in "${PRESENTATION_CONFIG_PATHS[@]}"; do
      require_file "$path"
      sha256sum -- "$path"
    done
    for path in \
      "$HOME/.config/hypr/monitors.conf" \
      "$HOME/.config/hypr/hyprland.conf" \
      "$HOME/.config/scopebuddy/scb.conf"; do
      [[ -f $path ]] && sha256sum -- "$path"
    done
    awk -F '\t' -v OFS='\t' '
      { print $1,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12 }
    ' "$PRESENTATION_MATRIX_FILE" | sha256sum | \
      awk -v path="$PRESENTATION_MATRIX_FILE#definitions" '{ print $1 "  " path }'
  fi
}

combined_config_hash() {
  config_hashes | sha256sum | awk '{ print $1 }'
}

current_boot_id() {
  require_file "$BOOT_ID_FILE"
  local boot_id
  read -r boot_id < "$BOOT_ID_FILE"
  [[ $boot_id =~ ^[A-Za-z0-9-]+$ ]] || die "invalid boot ID in $BOOT_ID_FILE"
  printf '%s\n' "$boot_id"
}

bool_to_int() {
  [[ $1 == true ]] && printf '1\n' || printf '0\n'
}

hypr_option_bool() {
  local option=$1 data value
  data=$(hyprctl -j getoption "$option" 2>&1) || die "hyprctl getoption $option failed: $data"
  value=$(jq -r 'if has("int") then (.int != 0) elif has("set") then .set else error("no boolean value") end' \
    <<< "$data") || die "could not parse Hyprland option $option: $data"
  [[ $value == true || $value == false ]] || die "could not parse Hyprland option $option: $data"
  printf '%s\n' "$value"
}

normalized_hypr_version() {
  local data
  data=$(hyprctl -j version 2>&1) || die "hyprctl version failed: $data"
  jq -ceS '{branch,commit,version,dirty,tag,commits,
    buildAquamarine,buildHyprlang,buildHyprutils,buildHyprcursor,buildHyprgraphics,
    systemAquamarine,systemHyprlang,systemHyprutils,systemHyprcursor,systemHyprgraphics,
    abiHash,flags}' <<< "$data" || die "could not normalize Hyprland version: $data"
}

gamescope_version() {
  local binary=$1 output
  output=$("$binary" --version 2>&1) || die "could not execute $binary --version: $output"
  # Strip Gamescope's console colour sequences so the frozen receipt is readable.
  printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g' | tail -n 1
}

verify_cached_package() {
  local package=$1 signature=$2 receipt=$3 output
  require_file "$package"
  require_file "$signature"
  command -v pacman-key >/dev/null || die "pacman-key not found; cannot verify cached gamescope package"
  if ! output=$(pacman-key --verify "$signature" "$package" 2>&1); then
    die "cached gamescope package signature verification failed: $output"
  fi
  {
    sha256sum -- "$package" "$signature"
    printf '%s\n' "$output"
  } > "$receipt"
}

resolve_gamescope() {
  local run_dir=$1 source=$GAMESCOPE_SOURCE requested package signature version_root extract_tmp
  local system_bin
  GAMESCOPE_BIN=""
  GAMESCOPE_BIN_DIR=""
  GAMESCOPE_SCRIPT_PATH=""
  GAMESCOPE_BIN_HASH=""
  GAMESCOPE_REAPER_HASH=""
  GAMESCOPE_VERSION=""
  if [[ $GAMESCOPE_MODE == bypass ]]; then
    GAMESCOPE_ARGS=""
    return
  fi

  case $source in
    system)
      system_bin=$(command -v gamescope) || die "gamescope not found"
      GAMESCOPE_BIN=$(readlink -f -- "$system_bin")
      GAMESCOPE_BIN_DIR=$(dirname -- "$GAMESCOPE_BIN")
      if [[ -d ${GAMESCOPE_BIN_DIR%/bin}/share/gamescope/scripts ]]; then
        GAMESCOPE_SCRIPT_PATH=${GAMESCOPE_BIN_DIR%/bin}/share/gamescope/scripts
      else
        GAMESCOPE_SCRIPT_PATH=/usr/share/gamescope/scripts
      fi
      ;;
    /*)
      GAMESCOPE_BIN=$(readlink -f -- "$source")
      GAMESCOPE_BIN_DIR=$(dirname -- "$GAMESCOPE_BIN")
      if [[ -d ${GAMESCOPE_BIN_DIR%/bin}/share/gamescope/scripts ]]; then
        GAMESCOPE_SCRIPT_PATH=${GAMESCOPE_BIN_DIR%/bin}/share/gamescope/scripts
      else
        GAMESCOPE_SCRIPT_PATH=${SKYRIM_BENCHMARK_GAMESCOPE_SCRIPT_PATH:-/usr/share/gamescope/scripts}
      fi
      ;;
    cached-*|cached:*)
      requested=${source#cached-}
      requested=${requested#cached:}
      [[ $requested =~ ^[0-9][0-9A-Za-z.+_-]*$ ]] || die "invalid cached gamescope version: $requested"
      package=/var/cache/pacman/pkg/gamescope-${requested}-x86_64.pkg.tar.zst
      if [[ ! -f $package && $requested != *-* ]]; then
        local -a matches=(/var/cache/pacman/pkg/gamescope-"$requested"-*-x86_64.pkg.tar.zst)
        (( ${#matches[@]} == 1 )) || die "expected one cached package for gamescope $requested"
        package=${matches[0]}
      fi
      signature=$package.sig
      mkdir -p -- "$STATE_DIR/tools"
      verify_cached_package "$package" "$signature" "$run_dir/gamescope-package-verification.txt"
      version_root=$STATE_DIR/tools/$(basename -- "$package" .pkg.tar.zst)
      if [[ ! -x $version_root/usr/bin/gamescope ]]; then
        command -v bsdtar >/dev/null || die "bsdtar not found; cannot extract cached gamescope"
        extract_tmp=$(mktemp -d "$STATE_DIR/tools/.gamescope-extract.XXXXXX")
        if ! bsdtar -xf "$package" -C "$extract_tmp"; then
          rm -rf -- "$extract_tmp"
          die "could not extract cached gamescope package"
        fi
        [[ -x $extract_tmp/usr/bin/gamescope && -x $extract_tmp/usr/bin/gamescopereaper ]] \
          || { rm -rf -- "$extract_tmp"; die "cached package lacks gamescope or gamescopereaper"; }
        mv -- "$extract_tmp" "$version_root"
      fi
      GAMESCOPE_BIN=$version_root/usr/bin/gamescope
      GAMESCOPE_BIN_DIR=$version_root/usr/bin
      GAMESCOPE_SCRIPT_PATH=$version_root/usr/share/gamescope/scripts
      ;;
  esac

  [[ -x $GAMESCOPE_BIN ]] || die "selected gamescope is not executable: $GAMESCOPE_BIN"
  [[ -x $GAMESCOPE_BIN_DIR/gamescopereaper ]] \
    || die "selected gamescope directory lacks matching gamescopereaper: $GAMESCOPE_BIN_DIR"
  [[ -d $GAMESCOPE_SCRIPT_PATH ]] || die "gamescope script directory missing: $GAMESCOPE_SCRIPT_PATH"
  GAMESCOPE_BIN_HASH=$(sha256sum -- "$GAMESCOPE_BIN" | awk '{print $1}')
  GAMESCOPE_REAPER_HASH=$(sha256sum -- "$GAMESCOPE_BIN_DIR/gamescopereaper" | awk '{print $1}')
  GAMESCOPE_VERSION=$(gamescope_version "$GAMESCOPE_BIN")
  if [[ $source == cached-* || $source == cached:* ]]; then
    version_root=${requested%%-*}
    [[ $GAMESCOPE_VERSION == *"$version_root"* ]] \
      || die "selected binary reports '$GAMESCOPE_VERSION', expected $version_root"
  fi
}

build_gamescope_args() {
  if [[ $GAMESCOPE_MODE == bypass ]]; then
    GAMESCOPE_ARGS=""
    return
  fi
  GAMESCOPE_ARGS="-f --grab --backend $GAMESCOPE_BACKEND --prefer-output $CONNECTOR --force-windows-fullscreen --mangoapp"
  if [[ $EXPLICIT_NESTED == 1 ]]; then
    GAMESCOPE_ARGS+=" -w $GAME_WIDTH -h $GAME_HEIGHT -S $SCALER -F $FILTER"
  fi
  GAMESCOPE_ARGS+=" -W $OUTPUT_WIDTH -H $OUTPUT_HEIGHT"
  if (( FPS_CAP > 0 )); then
    GAMESCOPE_ARGS+=" --framerate-limit $FPS_CAP"
  fi
}

monitor_data() {
  if [[ -n ${SKYRIM_BENCHMARK_MONITORS_JSON:-} ]]; then
    cat -- "$SKYRIM_BENCHMARK_MONITORS_JSON"
  else
    local data
    if ! data=$(hyprctl -j monitors 2>&1); then
      die "hyprctl monitors failed: $data"
    fi
    if ! jq -e . >/dev/null 2>&1 <<< "$data"; then
      die "hyprctl returned non-JSON monitor data: $data"
    fi
    printf '%s\n' "$data"
  fi
}

normalize_monitor_json() {
  jq -ceS '[.[] | select((.disabled // false) == false) | {
    name,description,make,model,serial,width,height,refreshRate,x,y,scale,transform,
    dpmsStatus,vrr
  }] | sort_by(.name)'
}

normalized_monitor_topology() {
  monitor_data | normalize_monitor_json
}

verify_frozen_topology() {
  local run_dir=$1 current prepared current_hash
  require_file "$run_dir/prepared-monitor-topology.json"
  prepared=$(jq -ceS . "$run_dir/prepared-monitor-topology.json") \
    || die "prepared monitor topology is invalid"
  current=$(normalized_monitor_topology) || die "could not normalize current monitor topology"
  current_hash=$(printf '%s\n' "$current" | sha256sum | awk '{print $1}')
  [[ $current == "$prepared" && $current_hash == "$MONITOR_TOPOLOGY_HASH" ]] \
    || die "enabled monitor topology changed after queueing"
}

focused_monitor() {
  monitor_data | jq -ce 'first(.[] | select(.focused == true))'
}

resolve_connector() {
  local monitor actual
  monitor=$(focused_monitor) || die "no focused Hyprland monitor"
  actual=$(jq -r '.name' <<< "$monitor")
  if [[ $PROFILE_CONNECTOR == focused ]]; then
    CONNECTOR=$actual
  else
    CONNECTOR=$PROFILE_CONNECTOR
  fi
}

verify_monitor() {
  local monitor name width height refresh
  monitor=$(focused_monitor) || die "no focused Hyprland monitor"
  name=$(jq -r '.name' <<< "$monitor")
  width=$(jq -r '.width' <<< "$monitor")
  height=$(jq -r '.height' <<< "$monitor")
  refresh=$(jq -r '.refreshRate | round' <<< "$monitor")

  [[ $name == "$CONNECTOR" ]] || die "focused monitor is $name, expected $CONNECTOR"
  [[ $width == "$OUTPUT_WIDTH" && $height == "$OUTPUT_HEIGHT" ]] \
    || die "focused monitor is ${width}x${height}, expected ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}"
  [[ $refresh == "$REFRESH_HZ" ]] || die "focused monitor is ${refresh}Hz, expected ${REFRESH_HZ}Hz"
}

steam_library() {
  "$MODULE_DIR/../lib/steam-find-app-path.sh" "$APP_ID"
}

steam_build_id() {
  if [[ -n ${SKYRIM_BENCHMARK_STEAM_BUILD:-} ]]; then
    printf '%s\n' "$SKYRIM_BENCHMARK_STEAM_BUILD"
    return
  fi
  local library manifest build_id state_flags target_build
  library=$(steam_library)
  manifest=$library/steamapps/appmanifest_${APP_ID}.acf
  require_file "$manifest"
  build_id=$(awk -F '"' '/"buildid"/ { print $4; exit }' "$manifest")
  state_flags=$(awk -F '"' '/"StateFlags"/ { print $4; exit }' "$manifest")
  target_build=$(awk -F '"' '/"TargetBuildID"/ { print $4; exit }' "$manifest")
  [[ $state_flags == 4 && $target_build == 0 ]] \
    || die "Steam reports Skyrim is not fully installed and idle (StateFlags=$state_flags TargetBuildID=$target_build)"
  [[ $build_id =~ ^[0-9]+$ ]] || die "could not read Skyrim build ID"
  printf '%s\n' "$build_id"
}

prefs_ini_path() {
  if [[ -n $PREFS_INI_OVERRIDE ]]; then
    printf '%s\n' "$PREFS_INI_OVERRIDE"
    return
  fi
  local library
  library=$(steam_library)
  printf '%s/steamapps/compatdata/%s/pfx/drive_c/users/steamuser/Documents/My Games/Skyrim Special Edition/SkyrimPrefs.ini\n' \
    "$library" "$APP_ID"
}

skyrim_ini_path() {
  if [[ -n $SKYRIM_INI_OVERRIDE ]]; then
    printf '%s\n' "$SKYRIM_INI_OVERRIDE"
    return
  fi
  local prefs
  prefs=$(prefs_ini_path)
  printf '%s/Skyrim.ini\n' "$(dirname -- "$prefs")"
}

expected_skyrim_fov() {
  if [[ -n ${SKYRIM_FOV:-} ]]; then
    printf '%s\n' "$SKYRIM_FOV"
    return
  fi
  awk -v w="$GAME_WIDTH" -v h="$GAME_HEIGHT" 'BEGIN {
    pi=atan2(0,-1); base=80; half=(base/2)*pi/180
    fov=2*atan2(sin(half)/cos(half)*(w/h)/(16/9),1)*180/pi
    if (fov<base) fov=base
    if (fov>110) fov=110
    printf "%.4f",fov
  }'
}

freeze_generated_inis() {
  local run_dir=$1 prefs skyrim expected_dir fov
  prefs=$(prefs_ini_path)
  skyrim=$(skyrim_ini_path)
  require_file "$prefs"
  require_file "$skyrim"
  expected_dir=$(mktemp -d "$run_dir/.expected-inis.XXXXXX")
  fov=$(expected_skyrim_fov)
  sed -e "s/@WIDTH@/$GAME_WIDTH/g" -e "s/@HEIGHT@/$GAME_HEIGHT/g" \
    "$MODULE_DIR/SkyrimPrefs.igpu.ini" > "$expected_dir/SkyrimPrefs.ini"
  sed -e "s/@FOV@/$fov/g" "$MODULE_DIR/Skyrim.ini" > "$expected_dir/Skyrim.ini"
  if ! cmp -s -- "$expected_dir/SkyrimPrefs.ini" "$prefs"; then
    rm -rf -- "$expected_dir"
    die "generated SkyrimPrefs.ini content does not match the prepared display/profile"
  fi
  if ! cmp -s -- "$expected_dir/Skyrim.ini" "$skyrim"; then
    rm -rf -- "$expected_dir"
    die "generated Skyrim.ini content does not match the prepared profile"
  fi
  PREFS_INI_HASH=$(sha256sum -- "$prefs" | awk '{print $1}')
  SKYRIM_INI_HASH=$(sha256sum -- "$skyrim" | awk '{print $1}')
  cp -- "$prefs" "$run_dir/activated-SkyrimPrefs.ini"
  cp -- "$skyrim" "$run_dir/activated-Skyrim.ini"
  {
    printf 'SkyrimPrefs.ini\t%s\t%s\n' "$PREFS_INI_HASH" "$prefs"
    printf 'Skyrim.ini\t%s\t%s\n' "$SKYRIM_INI_HASH" "$skyrim"
  } > "$run_dir/activated-ini-hashes.tsv"
  rm -rf -- "$expected_dir"
}

verify_frozen_inis() {
  local run_dir=$1 prefs skyrim expected_prefs expected_skyrim actual_prefs actual_skyrim
  prefs=$(prefs_ini_path)
  skyrim=$(skyrim_ini_path)
  [[ -f $run_dir/activated-ini-hashes.tsv && -f $run_dir/activated-SkyrimPrefs.ini && \
     -f $run_dir/activated-Skyrim.ini && -f $prefs && -f $skyrim ]] || return 1
  expected_prefs=$(awk -F '\t' '$1=="SkyrimPrefs.ini" {print $2; exit}' "$run_dir/activated-ini-hashes.tsv")
  expected_skyrim=$(awk -F '\t' '$1=="Skyrim.ini" {print $2; exit}' "$run_dir/activated-ini-hashes.tsv")
  actual_prefs=$(sha256sum -- "$prefs" | awk '{print $1}')
  actual_skyrim=$(sha256sum -- "$skyrim" | awk '{print $1}')
  [[ $actual_prefs == "$expected_prefs" && $actual_skyrim == "$expected_skyrim" ]] || return 1
  [[ $(sha256sum -- "$run_dir/activated-SkyrimPrefs.ini" | awk '{print $1}') == "$expected_prefs" ]] \
    || return 1
  [[ $(sha256sum -- "$run_dir/activated-Skyrim.ini" | awk '{print $1}') == "$expected_skyrim" ]] \
    || return 1
}

skyrim_running() {
  [[ ${SKYRIM_BENCHMARK_SKIP_PROCESS_CHECK:-0} == 1 ]] && return 1
  pgrep -f '[S]kyrimSE\.exe|[s]kse64_loader\.exe' >/dev/null 2>&1
}

write_prepared_env() {
  local run_dir=$1 run_id=$2 route=$3 warmup=$4 duration=$5 build_id=$6 config_hash=$7
  local tmp=$run_dir/prepared.env.tmp
  {
    printf 'RUN_ID=%q\n' "$run_id"
    printf 'RUN_KIND=%q\n' "$RUN_KIND"
    printf 'RUN_MATRIX_FILE=%q\n' "$RUN_MATRIX_FILE"
    printf 'PROFILE=%q\n' "$PROFILE"
    printf 'GAME_WIDTH=%q\n' "$GAME_WIDTH"
    printf 'GAME_HEIGHT=%q\n' "$GAME_HEIGHT"
    printf 'OUTPUT_WIDTH=%q\n' "$OUTPUT_WIDTH"
    printf 'OUTPUT_HEIGHT=%q\n' "$OUTPUT_HEIGHT"
    printf 'EXPLICIT_NESTED=%q\n' "$EXPLICIT_NESTED"
    printf 'SCALER=%q\n' "$SCALER"
    printf 'FILTER=%q\n' "$FILTER"
    printf 'CONNECTOR=%q\n' "$CONNECTOR"
    printf 'REFRESH_HZ=%q\n' "$REFRESH_HZ"
    printf 'ROUTE=%q\n' "$route"
    printf 'WARMUP_SECONDS=%q\n' "$warmup"
    printf 'DURATION_SECONDS=%q\n' "$duration"
    printf 'STEAM_BUILD_ID=%q\n' "$build_id"
    printf 'CONFIG_HASH=%q\n' "$config_hash"
    printf 'RUN_DIR=%q\n' "$run_dir"
    printf 'BOOT_ID_AT_QUEUE=%q\n' "$BOOT_ID_AT_QUEUE"
    printf 'CLEAN_BOOT=%q\n' "$CLEAN_BOOT"
    printf 'REPETITION=%q\n' "$REPETITION"
    if [[ $RUN_KIND == presentation ]]; then
      printf 'PRESENTATION_PROFILE=%q\n' "$PRESENTATION_PROFILE"
      printf 'DISPLAY_PROFILE=%q\n' "$DISPLAY_PROFILE"
      printf 'GAMESCOPE_SOURCE=%q\n' "$GAMESCOPE_SOURCE"
      printf 'GAMESCOPE_MODE=%q\n' "$GAMESCOPE_MODE"
      printf 'GAMESCOPE_BIN=%q\n' "$GAMESCOPE_BIN"
      printf 'GAMESCOPE_BIN_DIR=%q\n' "$GAMESCOPE_BIN_DIR"
      printf 'GAMESCOPE_SCRIPT_PATH=%q\n' "$GAMESCOPE_SCRIPT_PATH"
      printf 'GAMESCOPE_BIN_HASH=%q\n' "$GAMESCOPE_BIN_HASH"
      printf 'GAMESCOPE_REAPER_HASH=%q\n' "$GAMESCOPE_REAPER_HASH"
      printf 'GAMESCOPE_VERSION=%q\n' "$GAMESCOPE_VERSION"
      printf 'GAMESCOPE_ARGS=%q\n' "$GAMESCOPE_ARGS"
      printf 'GAMESCOPE_BACKEND=%q\n' "$GAMESCOPE_BACKEND"
      printf 'OVERLAY_POLICY=%q\n' "$OVERLAY_POLICY"
      printf 'HYPR_VFR=%q\n' "$HYPR_VFR"
      printf 'HYPR_ALLOW_TEARING=%q\n' "$HYPR_ALLOW_TEARING"
      printf 'HYPR_IMMEDIATE=%q\n' "$HYPR_IMMEDIATE"
      printf 'HYPR_VFR_AT_QUEUE=%q\n' "$HYPR_VFR_AT_QUEUE"
      printf 'HYPR_ALLOW_TEARING_AT_QUEUE=%q\n' "$HYPR_ALLOW_TEARING_AT_QUEUE"
      printf 'FPS_CAP=%q\n' "$FPS_CAP"
      printf 'HYPR_VERSION_HASH=%q\n' "$HYPR_VERSION_HASH"
      printf 'KERNEL_RELEASE=%q\n' "$KERNEL_RELEASE"
      printf 'MONITOR_TOPOLOGY_HASH=%q\n' "$MONITOR_TOPOLOGY_HASH"
    fi
  } > "$tmp"
  mv -- "$tmp" "$run_dir/prepared.env"
}

load_prepared() {
  local run_id=$1 env_file
  env_file=$RUNS_DIR/$run_id/prepared.env
  require_file "$env_file"
  RUN_KIND=legacy
  RUN_MATRIX_FILE=$MATRIX_FILE
  CLEAN_BOOT=false
  REPETITION=""
  # The file is generated only by this script from validated profile and matrix values.
  # shellcheck disable=SC1090,SC1091
  source "$env_file"
  [[ $RUN_ID == "$run_id" ]] || die "prepared run ID mismatch"
  RUN_KIND=${RUN_KIND:-legacy}
  RUN_MATRIX_FILE=${RUN_MATRIX_FILE:-$MATRIX_FILE}
  CLEAN_BOOT=${CLEAN_BOOT:-false}
  REPETITION=${REPETITION:-}
}

write_state() {
  local run_id=$1 state=$2
  printf '%s\n' "$state" > "$RUNS_DIR/$run_id/status"
}

verify_prepared() {
  local run_id=$1 current_hash current_build matrix_profile selected selected_hash reaper_hash current_version
  load_prepared "$run_id"
  if [[ $RUN_KIND == presentation ]]; then
    require_file "$PRESENTATION_MATRIX_FILE"
    [[ $RUN_MATRIX_FILE == "$PRESENTATION_MATRIX_FILE" ]] \
      || die "prepared presentation matrix path changed"
    matrix_profile=$(tsv_field "$RUN_MATRIX_FILE" "$run_id" profile) \
      || die "run missing from presentation matrix: $run_id"
    [[ $matrix_profile == "$PRESENTATION_PROFILE" ]] \
      || die "matrix profile changed from $PRESENTATION_PROFILE to $matrix_profile"
    load_presentation_profile "$PRESENTATION_PROFILE"
    verify_one_factor "$run_id"
    [[ $GAMESCOPE_ARGS == "$(build_gamescope_args; printf '%s' "$GAMESCOPE_ARGS")" ]] \
      || die "generated gamescope arguments changed after queueing"
  else
    load_profile "$PROFILE"
    matrix_profile=$(matrix_field "$run_id" 4) || die "run missing from matrix: $run_id"
    [[ $matrix_profile == "$PROFILE" ]] || die "matrix profile changed from $PROFILE to $matrix_profile"
  fi
  require_file "$MANGOHUD_CONFIG_FILE"
  for command_name in mangoapp jq hyprctl; do
    command -v "$command_name" >/dev/null || die "$command_name not found"
  done
  if [[ $RUN_KIND == legacy || $GAMESCOPE_MODE == enabled ]]; then
    command -v gamescope >/dev/null || die "gamescope not found"
  fi
  verify_monitor
  current_hash=$(combined_config_hash)
  [[ $current_hash == "$CONFIG_HASH" ]] || die "benchmark configuration changed after queueing; invalidate and re-queue $run_id"
  current_build=$(steam_build_id)
  [[ $current_build == "$STEAM_BUILD_ID" ]] || die "Skyrim build changed from $STEAM_BUILD_ID to $current_build"
  if [[ $RUN_KIND == presentation ]]; then
    [[ $(hypr_option_bool debug:vfr) == "$HYPR_VFR_AT_QUEUE" ]] \
      || die "live debug:vfr drifted from queue-time value $HYPR_VFR_AT_QUEUE"
    [[ $(hypr_option_bool general:allow_tearing) == "$HYPR_ALLOW_TEARING_AT_QUEUE" ]] \
      || die "live general:allow_tearing drifted from queue-time value $HYPR_ALLOW_TEARING_AT_QUEUE"
    [[ $(normalized_hypr_version | sha256sum | awk '{print $1}') == "$HYPR_VERSION_HASH" ]] \
      || die "Hyprland/Aquamarine version changed after queueing"
    [[ $(uname -r) == "$KERNEL_RELEASE" ]] || die "kernel changed after queueing"
    verify_frozen_topology "$RUNS_DIR/$run_id"
    if [[ $GAMESCOPE_MODE == enabled ]]; then
      require_file "$GAMESCOPE_BIN"
      require_file "$GAMESCOPE_BIN_DIR/gamescopereaper"
      [[ -d $GAMESCOPE_SCRIPT_PATH ]] || die "gamescope script path disappeared: $GAMESCOPE_SCRIPT_PATH"
      selected_hash=$(sha256sum -- "$GAMESCOPE_BIN" | awk '{print $1}')
      reaper_hash=$(sha256sum -- "$GAMESCOPE_BIN_DIR/gamescopereaper" | awk '{print $1}')
      [[ $selected_hash == "$GAMESCOPE_BIN_HASH" ]] || die "selected gamescope binary changed after queueing"
      [[ $reaper_hash == "$GAMESCOPE_REAPER_HASH" ]] || die "selected gamescopereaper changed after queueing"
      current_version=$(gamescope_version "$GAMESCOPE_BIN")
      [[ $current_version == "$GAMESCOPE_VERSION" ]] || die "selected gamescope version output changed"
      if [[ $GAMESCOPE_SOURCE == system ]]; then
        selected=$(readlink -f -- "$(command -v gamescope)")
        [[ $selected == "$GAMESCOPE_BIN" ]] || die "system gamescope path changed from $GAMESCOPE_BIN to $selected"
      fi
    fi
    local config_errors
    config_errors=$(hyprctl configerrors 2>&1) || die "hyprctl configerrors failed: $config_errors"
    [[ -z $config_errors ]] || die "Hyprland has configuration errors: $config_errors"
  fi
}

boot_gate_state() {
  if [[ $CLEAN_BOOT == true && $(current_boot_id) == "$BOOT_ID_AT_QUEUE" ]]; then
    printf 'WAITING_FOR_REBOOT\n'
  else
    printf 'READY\n'
  fi
}

print_receipt() {
  local run_id=$1 state=${2:-READY}
  load_prepared "$run_id"
  printf 'RUN=%s\n' "$RUN_ID"
  printf 'RUN_KIND=%s\n' "$RUN_KIND"
  printf 'PROFILE=%s\n' "$PROFILE"
  printf 'GAME=%sx%s\n' "$GAME_WIDTH" "$GAME_HEIGHT"
  printf 'NESTED=%sx%s\n' "$GAME_WIDTH" "$GAME_HEIGHT"
  printf 'OUTPUT=%sx%s@%s %s\n' "$OUTPUT_WIDTH" "$OUTPUT_HEIGHT" "$REFRESH_HZ" "$CONNECTOR"
  printf 'SCALER=%s\n' "$SCALER"
  printf 'FILTER=%s\n' "$FILTER"
  printf 'HUD=enabled\n'
  printf 'RECORDING=manual Left Shift+F2\n'
  printf 'MANGOHUD_RECORDING=manual Left Shift+F2\n'
  if [[ $RUN_KIND == presentation ]]; then
    printf 'SYSTEM_TRACE=automatic\n'
    printf 'PRESENTATION_PROFILE=%s\n' "$PRESENTATION_PROFILE"
    printf 'REPETITION=%s\n' "$REPETITION"
    printf 'CLEAN_BOOT=%s\n' "$CLEAN_BOOT"
    printf 'BOOT_ID_AT_QUEUE=%s\n' "$BOOT_ID_AT_QUEUE"
    printf 'BOOT_ID_CURRENT=%s\n' "$(current_boot_id)"
    printf 'GAMESCOPE_MODE=%s\n' "$GAMESCOPE_MODE"
    printf 'GAMESCOPE_SOURCE=%s\n' "$GAMESCOPE_SOURCE"
    printf 'GAMESCOPE_BIN=%s\n' "${GAMESCOPE_BIN:-none}"
    printf 'GAMESCOPE_VERSION=%s\n' "${GAMESCOPE_VERSION:-bypassed}"
    printf 'GAMESCOPE_BACKEND=%s\n' "$GAMESCOPE_BACKEND"
    printf 'GAMESCOPE_ARGS=%s\n' "${GAMESCOPE_ARGS:-none}"
    printf 'OVERLAY_POLICY=%s\n' "$OVERLAY_POLICY"
    printf 'HYPR_VFR_EXPECTED=%s\n' "$HYPR_VFR"
    printf 'HYPR_VFR_CURRENT=%s\n' "$(hypr_option_bool debug:vfr)"
    printf 'HYPR_ALLOW_TEARING_EXPECTED=%s\n' "$HYPR_ALLOW_TEARING"
    printf 'HYPR_ALLOW_TEARING_CURRENT=%s\n' "$(hypr_option_bool general:allow_tearing)"
    printf 'HYPR_IMMEDIATE_EXPECTED=%s\n' "$HYPR_IMMEDIATE"
    printf 'HYPR_VERSION_HASH=%s\n' "$HYPR_VERSION_HASH"
    printf 'KERNEL_RELEASE=%s\n' "$KERNEL_RELEASE"
    printf 'MONITOR_TOPOLOGY_HASH=%s\n' "$MONITOR_TOPOLOGY_HASH"
    printf 'FPS_CAP=%s\n' "$FPS_CAP"
  fi
  printf 'ROUTE=%s\n' "$ROUTE"
  printf 'WARMUP=%ss\n' "$WARMUP_SECONDS"
  printf 'DURATION=%ss\n' "$DURATION_SECONDS"
  printf 'STEAM_BUILD=%s\n' "$STEAM_BUILD_ID"
  # STATE is last so short-circuiting readers such as `grep -q STATE=READY`
  # cannot close the pipe while the receipt is still being written.
  printf 'STATE=%s\n' "$state"
}

queue_run() {
  local run_id=$1 status profile route warmup duration run_dir build_id config_hash prepare_dir
  require_file "$MATRIX_FILE"
  require_file "$PROFILES_FILE"
  locate_run "$run_id"
  status=$(run_field "$run_id" status 2)
  [[ $status == planned ]] || die "run $run_id has status $status, expected planned"
  [[ ! -e $ARMED_FILE && ! -e $ACTIVE_FILE ]] || die "another benchmark run is already armed or active"

  profile=$(run_field "$run_id" profile 4)
  route=$(run_field "$run_id" route 8)
  warmup=$(run_field "$run_id" warmup_s 9)
  duration=$(run_field "$run_id" duration_s 10)
  if [[ $RUN_KIND == presentation ]]; then
    CLEAN_BOOT=$(run_field "$run_id" clean_boot)
    REPETITION=$(run_field "$run_id" repetition)
    [[ $CLEAN_BOOT == true || $CLEAN_BOOT == false ]] || die "clean_boot must be true or false"
    [[ $REPETITION =~ ^(diagnostic|short-1|short-2|soak)$ ]] || die "invalid repetition: $REPETITION"
    load_presentation_profile "$profile"
    verify_one_factor "$run_id"
    verify_repetition_predecessor "$run_id"
    HYPR_VFR_AT_QUEUE=$(hypr_option_bool debug:vfr)
    HYPR_ALLOW_TEARING_AT_QUEUE=$(hypr_option_bool general:allow_tearing)
    [[ $HYPR_VFR_AT_QUEUE == "$HYPR_VFR" ]] \
      || die "presentation profile expects VFR=$HYPR_VFR but queue-time state is $HYPR_VFR_AT_QUEUE"
    if [[ $REPETITION != diagnostic ]]; then
      [[ $HYPR_ALLOW_TEARING == false ]] \
        || die "$run_id would re-enable tearing; formal presentation profiles must keep the shared allow_tearing=false policy"
      [[ $HYPR_ALLOW_TEARING_AT_QUEUE == false ]] \
        || die "$run_id requires the persisted shared allow_tearing=false policy before queueing"
    fi
    HYPR_VERSION_JSON=$(normalized_hypr_version)
    HYPR_VERSION_HASH=$(printf '%s\n' "$HYPR_VERSION_JSON" | sha256sum | awk '{print $1}')
    KERNEL_RELEASE=$(uname -r)
  else
    CLEAN_BOOT=false
    REPETITION=legacy
    load_profile "$profile"
  fi
  if skyrim_running && [[ $CLEAN_BOOT != true ]]; then
    die "Skyrim is running; close it before queueing a run"
  fi
  resolve_connector
  verify_monitor
  require_file "$MANGOHUD_CONFIG_FILE"
  for command_name in mangoapp jq hyprctl; do
    command -v "$command_name" >/dev/null || die "$command_name not found"
  done
  build_id=$(steam_build_id)
  BOOT_ID_AT_QUEUE=$(current_boot_id)

  mkdir -p -- "$STATE_DIR" "$RUNS_DIR"
  prepare_dir=$(mktemp -d "$STATE_DIR/.prepare-${run_id}.XXXXXX")
  if [[ $RUN_KIND == presentation ]]; then
    resolve_gamescope "$prepare_dir"
    build_gamescope_args
  fi
  config_hash=$(combined_config_hash)

  run_dir=$RUNS_DIR/$run_id
  if [[ -e $run_dir ]]; then
    rm -rf -- "$prepare_dir"
    die "run evidence already exists: $run_dir"
  fi
  mkdir -p -- "$run_dir"
  if [[ -f $prepare_dir/gamescope-package-verification.txt ]]; then
    mv -- "$prepare_dir/gamescope-package-verification.txt" "$run_dir/"
  fi
  rm -rf -- "$prepare_dir"
  config_hashes > "$run_dir/prepared-config-hashes.tsv"
  focused_monitor > "$run_dir/prepared-monitor.json"
  local monitor_topology
  monitor_topology=$(normalized_monitor_topology) || die "could not capture enabled monitor topology"
  MONITOR_TOPOLOGY_HASH=$(printf '%s\n' "$monitor_topology" | sha256sum | awk '{print $1}')
  printf '%s\n' "$monitor_topology" | jq . > "$run_dir/prepared-monitor-topology.json"
  write_prepared_env "$run_dir" "$run_id" "$route" "$warmup" "$duration" "$build_id" "$config_hash"
  if [[ $RUN_KIND == presentation ]]; then
    printf '%s\n' "$HYPR_VERSION_JSON" | jq . > "$run_dir/prepared-hypr-version.json"
    jq -n \
      --arg run_id "$run_id" --arg profile "$PRESENTATION_PROFILE" --arg display_profile "$PROFILE" \
      --arg route "$route" --arg repetition "$REPETITION" --arg connector "$CONNECTOR" \
      --arg gamescope_mode "$GAMESCOPE_MODE" --arg gamescope_source "$GAMESCOPE_SOURCE" \
      --arg gamescope_bin "$GAMESCOPE_BIN" --arg gamescope_version "$GAMESCOPE_VERSION" \
      --arg gamescope_hash "$GAMESCOPE_BIN_HASH" --arg gamescopereaper_hash "$GAMESCOPE_REAPER_HASH" \
      --arg backend "$GAMESCOPE_BACKEND" --arg gamescope_args "$GAMESCOPE_ARGS" \
      --arg overlay "$OVERLAY_POLICY" --arg vfr "$HYPR_VFR" --arg allow_tearing "$HYPR_ALLOW_TEARING" \
      --arg vfr_at_queue "$HYPR_VFR_AT_QUEUE" --arg tearing_at_queue "$HYPR_ALLOW_TEARING_AT_QUEUE" \
      --arg immediate "$HYPR_IMMEDIATE" --arg boot_id "$BOOT_ID_AT_QUEUE" \
      --arg hypr_version_hash "$HYPR_VERSION_HASH" --arg kernel_release "$KERNEL_RELEASE" \
      --arg topology_hash "$MONITOR_TOPOLOGY_HASH" \
      --arg build_id "$build_id" --arg config_hash "$config_hash" \
      --argjson game_width "$GAME_WIDTH" --argjson game_height "$GAME_HEIGHT" \
      --argjson output_width "$OUTPUT_WIDTH" --argjson output_height "$OUTPUT_HEIGHT" \
      --argjson refresh_hz "$REFRESH_HZ" --argjson warmup_seconds "$warmup" \
      --argjson duration_seconds "$duration" --argjson clean_boot "$CLEAN_BOOT" --argjson fps_cap "$FPS_CAP" \
      '{schema:2, run_id:$run_id, kind:"presentation", state:"armed", profile:$profile,
        display_profile:$display_profile, route:$route, repetition:$repetition, clean_boot:$clean_boot,
        game:{width:$game_width,height:$game_height},
        output:{width:$output_width,height:$output_height,refresh_hz:$refresh_hz,connector:$connector,
          topology_sha256:$topology_hash},
        gamescope:{mode:$gamescope_mode,source:$gamescope_source,binary:$gamescope_bin,
          version:$gamescope_version,sha256:$gamescope_hash,reaper_sha256:$gamescopereaper_hash,
          backend:$backend,args:$gamescope_args}, overlay_policy:$overlay,
        hypr:{vfr:($vfr=="true"),allow_tearing:($allow_tearing=="true"),immediate:($immediate=="true"),
          vfr_at_queue:($vfr_at_queue=="true"),allow_tearing_at_queue:($tearing_at_queue=="true"),
          version_hash:$hypr_version_hash}, kernel_release:$kernel_release,
        fps_cap:$fps_cap, warmup_seconds:$warmup_seconds, duration_seconds:$duration_seconds,
        hud:true, mangohud_recording:"manual Left Shift+F2", system_trace:"automatic",
        boot_id_at_queue:$boot_id, steam_build_id:$build_id, config_hash:$config_hash,
        prepared_at:(now | todateiso8601)}' > "$run_dir/prepared.json"
  else
    jq -n \
    --arg run_id "$run_id" --arg profile "$PROFILE" --arg route "$route" \
    --arg connector "$CONNECTOR" --arg scaler "$SCALER" --arg filter "$FILTER" \
    --arg build_id "$build_id" --arg config_hash "$config_hash" \
    --argjson game_width "$GAME_WIDTH" --argjson game_height "$GAME_HEIGHT" \
    --argjson output_width "$OUTPUT_WIDTH" --argjson output_height "$OUTPUT_HEIGHT" \
    --argjson warmup_seconds "$warmup" --argjson duration_seconds "$duration" \
    '{schema:1, run_id:$run_id, state:"armed", profile:$profile, route:$route,
      game:{width:$game_width,height:$game_height}, output:{width:$output_width,height:$output_height,connector:$connector},
      scaler:$scaler, filter:$filter, warmup_seconds:$warmup_seconds, duration_seconds:$duration_seconds,
      hud:true, recording:"manual Left Shift+F2", steam_build_id:$build_id, config_hash:$config_hash,
      prepared_at:(now | todateiso8601)}' > "$run_dir/prepared.json"
  fi
  write_state "$run_id" armed
  printf '%s\n' "$run_id" > "$ARMED_FILE"
  update_run_status "$run_id" armed
  status_command
}

status_command() {
  local run_id state trace_state
  if [[ -f $ARMED_FILE ]]; then
    run_id=$(<"$ARMED_FILE")
    state=$(<"$RUNS_DIR/$run_id/status")
    [[ $state == armed ]] || die "armed pointer and run state disagree for $run_id"
    verify_prepared "$run_id"
    state=$(boot_gate_state)
    print_receipt "$run_id" "$state"
    return
  fi
  if [[ -f $ACTIVE_FILE ]]; then
    run_id=$(<"$ACTIVE_FILE")
    state=$(<"$RUNS_DIR/$run_id/status")
    load_prepared "$run_id"
    printf 'RUN=%s\nSTATE=%s\nRUN_KIND=%s\n' "$run_id" "$state" "$RUN_KIND"
    if [[ $RUN_KIND == presentation ]]; then
      printf 'HUD=enabled\nMANGOHUD_RECORDING=manual Left Shift+F2\nSYSTEM_TRACE=automatic\n'
      trace_state=unknown
      [[ -f $RUNS_DIR/$run_id/trace-status ]] && trace_state=$(<"$RUNS_DIR/$run_id/trace-status")
      printf 'TRACE_STATE=%s\n' "$trace_state"
      [[ -f $RUNS_DIR/$run_id/runtime-verification.json ]] && printf 'RUNTIME_VERIFICATION=recorded\n' \
        || printf 'RUNTIME_VERIFICATION=pending\n'
    fi
    return
  fi
  printf 'STATE=NO_ACTIVE_RUN\n'
}

verify_launch_args() {
  local args=$1
  if [[ $RUN_KIND == presentation ]]; then
    [[ $args == "$GAMESCOPE_ARGS" ]] \
      || die "launch arguments differ from prepared exact string: expected '$GAMESCOPE_ARGS', got '$args'"
    if [[ $GAMESCOPE_MODE == bypass ]]; then
      [[ -z $args ]] || die "gamescope bypass must not receive gamescope arguments"
      [[ ${MANGOHUD:-0} == 1 ]] || die "gamescope bypass did not enable MangoHud directly"
    fi
    return
  fi
  [[ " $args " == *" --mangoapp "* ]] || die "launch arguments do not enable MangoApp"
  [[ " $args " == *" --force-windows-fullscreen "* ]] || die "launch arguments lost --force-windows-fullscreen"
  [[ " $args " != *" --force-grab-cursor "* ]] || die "launch arguments reintroduced --force-grab-cursor"
  [[ " $args " == *" -W $OUTPUT_WIDTH "* && " $args " == *" -H $OUTPUT_HEIGHT "* ]] \
    || die "launch output resolution does not match the prepared profile"
  if [[ $EXPLICIT_NESTED == 1 ]]; then
    [[ " $args " == *" -w $GAME_WIDTH "* && " $args " == *" -h $GAME_HEIGHT "* ]] \
      || die "launch nested resolution does not match the prepared profile"
    [[ " $args " == *" -S $SCALER "* && " $args " == *" -F $FILTER "* ]] \
      || die "launch scaler/filter does not match the prepared profile"
  else
    [[ " $args " != *" -w "* && " $args " != *" -h "* && " $args " != *" -F "* ]] \
      || die "native profile unexpectedly changes nested resolution or filter"
  fi
}

verify_generated_prefs() {
  local prefs
  prefs=$(prefs_ini_path)
  require_file "$prefs"
  grep -Fxq "iSize W=$GAME_WIDTH" "$prefs" || die "generated SkyrimPrefs.ini width does not match $GAME_WIDTH"
  grep -Fxq "iSize H=$GAME_HEIGHT" "$prefs" || die "generated SkyrimPrefs.ini height does not match $GAME_HEIGHT"
}

save_journal_cursor() {
  local scope=$1 output_file=$2 output cursor
  if [[ $scope == user ]]; then
    output=$(journalctl --user -b -n 0 --show-cursor --no-pager 2>&1) || {
      printf 'unavailable\t%s\n' "$(sanitize_cell "$output")" > "$output_file"
      return
    }
  else
    output=$(journalctl -b -k -n 0 --show-cursor --no-pager 2>&1) || {
      printf 'unavailable\t%s\n' "$(sanitize_cell "$output")" > "$output_file"
      return
    }
  fi
  cursor=$(awk '/^-- cursor:/ { sub(/^-- cursor: /, ""); print; exit }' <<< "$output")
  [[ -n $cursor ]] && printf '%s\n' "$cursor" > "$output_file" \
    || printf 'unavailable\tno cursor returned\n' > "$output_file"
}

apply_runtime_hypr() {
  local run_dir=$1 prior_vfr prior_tearing actual
  prior_vfr=$(hypr_option_bool debug:vfr)
  prior_tearing=$(hypr_option_bool general:allow_tearing)
  {
    printf 'PRIOR_VFR=%q\n' "$prior_vfr"
    printf 'PRIOR_ALLOW_TEARING=%q\n' "$prior_tearing"
  } > "$run_dir/runtime-hypr-before.env"
  hyprctl keyword debug:vfr "$HYPR_VFR" >/dev/null
  hyprctl keyword general:allow_tearing "$HYPR_ALLOW_TEARING" >/dev/null
  actual=$(hypr_option_bool debug:vfr)
  [[ $actual == "$HYPR_VFR" ]] || die "could not apply debug:vfr=$HYPR_VFR"
  actual=$(hypr_option_bool general:allow_tearing)
  [[ $actual == "$HYPR_ALLOW_TEARING" ]] || die "could not apply general:allow_tearing=$HYPR_ALLOW_TEARING"
  printf 'applied\n' > "$run_dir/runtime-hypr-status"
}

restore_runtime_hypr() {
  local run_id=$1 run_dir prior_vfr prior_tearing PRIOR_VFR="" PRIOR_ALLOW_TEARING=""
  run_dir=$RUNS_DIR/$run_id
  [[ -f $run_dir/runtime-hypr-before.env ]] || return 0
  [[ ! -f $run_dir/runtime-hypr-restored ]] || return 0
  # Generated by apply_runtime_hypr using parsed Hyprland booleans only.
  # shellcheck disable=SC1090,SC1091
  source "$run_dir/runtime-hypr-before.env"
  prior_vfr=$PRIOR_VFR
  prior_tearing=$PRIOR_ALLOW_TEARING
  hyprctl keyword debug:vfr "$prior_vfr" >/dev/null
  hyprctl keyword general:allow_tearing "$prior_tearing" >/dev/null
  [[ $(hypr_option_bool debug:vfr) == "$prior_vfr" ]] || die "failed to restore debug:vfr"
  [[ $(hypr_option_bool general:allow_tearing) == "$prior_tearing" ]] \
    || die "failed to restore general:allow_tearing"
  date --iso-8601=seconds > "$run_dir/runtime-hypr-restored"
}

find_role_pid() {
  local role=$1 instances signature
  [[ $role == hyprland ]] || return 1
  instances=$(hyprctl -j instances 2>/dev/null) || return 1
  signature=${HYPRLAND_INSTANCE_SIGNATURE:-}
  if [[ -n $signature ]]; then
    jq -r --arg signature "$signature" 'first(.[] | select(.instance==$signature)) | .pid // empty' \
      <<< "$instances"
  else
    jq -r 'first(.[]) | .pid // empty' <<< "$instances"
  fi
}

proc_parent() {
  local pid=$1
  awk '/^PPid:/ {print $2; exit}' "/proc/$pid/status" 2>/dev/null || true
}

pid_has_ancestor() {
  local pid=$1 ancestor=$2 parent _
  for _ in {1..64}; do
    [[ $pid == "$ancestor" ]] && return 0
    [[ $pid =~ ^[0-9]+$ && $pid -gt 1 ]] || return 1
    parent=$(proc_parent "$pid")
    [[ -n $parent && $parent != "$pid" ]] || return 1
    pid=$parent
  done
  return 1
}

find_launch_processes() {
  local game_pid parent exe name bypass_has_gamescope _
  while IFS= read -r game_pid; do
    [[ -n $game_pid ]] || continue
    if [[ $GAMESCOPE_MODE == bypass ]]; then
      parent=$game_pid
      bypass_has_gamescope=false
      for _ in {1..64}; do
        [[ $parent =~ ^[0-9]+$ && $parent -gt 1 ]] || break
        exe=$(readlink -f -- "/proc/$parent/exe" 2>/dev/null || true)
        name=${exe##*/}
        if [[ $name == gamescope ]]; then
          bypass_has_gamescope=true
          break
        fi
        parent=$(proc_parent "$parent")
      done
      [[ $bypass_has_gamescope == false ]] || continue
      printf '%s\t0\n' "$game_pid"
      return 0
    fi
    parent=$game_pid
    for _ in {1..64}; do
      [[ $parent =~ ^[0-9]+$ && $parent -gt 1 ]] || break
      exe=$(readlink -f -- "/proc/$parent/exe" 2>/dev/null || true)
      if [[ $exe == "$GAMESCOPE_BIN" ]]; then
        printf '%s\t%s\n' "$game_pid" "$parent"
        return 0
      fi
      parent=$(proc_parent "$parent")
    done
  done < <(pgrep -f '[S]kyrimSE\.exe' || true)
  return 1
}

trace_worker_exit() {
  local status=$1
  if (( status == 0 )); then
    printf 'stopped\n' > "$TRACE_STATUS_FILE"
  else
    printf 'failed\n' > "$TRACE_STATUS_FILE"
  fi
}

find_nested_xwayland() {
  local gamescope_pid=$1 pid
  [[ $gamescope_pid =~ ^[0-9]+$ && $gamescope_pid -gt 1 ]] || return 1
  while IFS= read -r pid; do
    pid_has_ancestor "$pid" "$gamescope_pid" && { printf '%s\n' "$pid"; return 0; }
  done < <(pgrep -x Xwayland || true)
  return 1
}

process_sample() {
  local pid=${1:-} stat rest start utime stime rss threads read_bytes write_bytes fds
  if [[ -z $pid || ! -r /proc/$pid/stat ]]; then
    printf '0\t0\t0\t0\t0\t0\t0\t0\t0'
    return
  fi
  if ! IFS= read -r stat < "/proc/$pid/stat" 2>/dev/null; then
    printf '0\t0\t0\t0\t0\t0\t0\t0\t0'
    return
  fi
  rest=${stat##*) }
  read -r _ _ _ _ _ _ _ _ _ _ _ utime stime _ _ _ _ _ _ start _ rss _ <<< "$rest"
  threads=$(awk '/^Threads:/ {print $2}' "/proc/$pid/status" 2>/dev/null || printf 0)
  read_bytes=$(awk '/^read_bytes:/ {print $2}' "/proc/$pid/io" 2>/dev/null || printf 0)
  write_bytes=$(awk '/^write_bytes:/ {print $2}' "/proc/$pid/io" 2>/dev/null || printf 0)
  fds=0
  [[ -d /proc/$pid/fd ]] && fds=$(printf '%s\n' /proc/"$pid"/fd/* | wc -l)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "$pid" "$start" "$utime" "$stime" "$rss" "${threads:-0}" \
    "${read_bytes:-0}" "${write_bytes:-0}" "$fds"
}

record_process_once() {
  local run_dir=$1 role=$2 pid=${3:-} cmdline exe
  [[ -n $pid && -r /proc/$pid/cmdline ]] || return 0
  grep -q $'\t'"$pid"$'\t' "$run_dir/processes.tsv" 2>/dev/null && return 0
  cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | sed 's/[[:space:]]*$//') || return 0
  exe=$(readlink -f -- "/proc/$pid/exe" 2>/dev/null || true)
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s%N)" "$pid" "$role" "$exe" \
    "$(sanitize_cell "$cmdline")" >> "$run_dir/processes.tsv"
}

apply_and_verify_client_state() {
  local run_dir=$1 gamescope_pid=${2:-} skyrim_pid=${3:-} clients address actual cmdline exe
  if [[ $GAMESCOPE_MODE == enabled && ! -f $run_dir/client-verification.tsv ]]; then
    [[ -n $gamescope_pid ]] || return 0
    clients=$(hyprctl -j clients 2>/dev/null) || return 0
    address=$(jq -r --argjson pid "$gamescope_pid" 'first(.[] | select(.pid == $pid)) | .address // empty' \
      <<< "$clients")
    [[ -n $address ]] || return 0
    hyprctl dispatch setprop "address:$address" immediate "$(bool_to_int "$HYPR_IMMEDIATE")" lock >/dev/null || return 0
    actual=$(hyprctl getprop "address:$address" immediate 2>/dev/null | \
      grep -Eo 'true|false' | tail -n 1) || return 0
    [[ $actual == "$HYPR_IMMEDIATE" ]] || actual=false-mismatch
    cmdline=$(tr '\0' ' ' < "/proc/$gamescope_pid/cmdline" 2>/dev/null || true)
    exe=$(readlink -f -- "/proc/$gamescope_pid/exe" 2>/dev/null || true)
    {
      printf 'address\t%s\n' "$address"
      printf 'pid\t%s\n' "$gamescope_pid"
      printf 'expected_immediate\t%s\n' "$HYPR_IMMEDIATE"
      printf 'actual_immediate\t%s\n' "$actual"
      printf 'expected_binary\t%s\n' "$GAMESCOPE_BIN"
      printf 'actual_binary\t%s\n' "$exe"
      printf 'expected_backend\t%s\n' "$GAMESCOPE_BACKEND"
      printf 'cmdline\t%s\n' "$(sanitize_cell "$cmdline")"
    } > "$run_dir/client-verification.tsv"
  fi

  if [[ -n $skyrim_pid && -r /proc/$skyrim_pid/maps ]]; then
    local game_overlay=false scope_overlay=false expected_game=false
    grep -q 'gameoverlayrenderer\.so' "/proc/$skyrim_pid/maps" && game_overlay=true
    if [[ -n $gamescope_pid && -r /proc/$gamescope_pid/maps ]] && \
       grep -q 'gameoverlayrenderer\.so' "/proc/$gamescope_pid/maps"; then
      scope_overlay=true
    fi
    [[ $OVERLAY_POLICY == game ]] && expected_game=true
    {
      printf 'policy\t%s\n' "$OVERLAY_POLICY"
      printf 'expected_game_overlay\t%s\n' "$expected_game"
      printf 'actual_game_overlay\t%s\n' "$game_overlay"
      printf 'expected_gamescope_overlay\tfalse\n'
      printf 'actual_gamescope_overlay\t%s\n' "$scope_overlay"
    } > "$run_dir/overlay-verification.tsv"
  fi
}

sample_hypr_state() {
  local run_dir=$1 timestamp=$2 verified_pid=${3:-0} skyrim_pid=${4:-0} address=${5:-}
  local monitors clients active immediate=null vfr allow_tearing topology=null
  monitors=$(hyprctl -j monitors all 2>/dev/null || printf 'null')
  clients=$(hyprctl -j clients 2>/dev/null || printf 'null')
  active=$(hyprctl -j activewindow 2>/dev/null || printf 'null')
  if [[ $clients != null && -n $address && $verified_pid -gt 0 ]]; then
    if jq -e --arg address "$address" --argjson pid "$verified_pid" \
      'any(.[]; .address==$address and .pid==$pid)' <<< "$clients" >/dev/null; then
      immediate=$(hyprctl getprop "address:$address" immediate 2>/dev/null | \
        grep -Eo 'true|false' | tail -n 1 || printf 'null')
    fi
  fi
  vfr=$(hypr_option_bool debug:vfr 2>/dev/null || printf 'null')
  allow_tearing=$(hypr_option_bool general:allow_tearing 2>/dev/null || printf 'null')
  if [[ $monitors != null ]]; then
    topology=$(normalize_monitor_json <<< "$monitors" 2>/dev/null || printf 'null')
  fi
  jq -cn --argjson timestamp_ns "$timestamp" --argjson monitors "$monitors" \
    --argjson clients "$clients" --argjson active "$active" --arg address "$address" \
    --argjson verified_pid "$verified_pid" --argjson skyrim_pid "${skyrim_pid:-0}" \
    --argjson immediate "$immediate" --argjson topology "$topology" \
    --argjson vfr "$vfr" --argjson allow_tearing "$allow_tearing" \
    '{timestamp_ns:$timestamp_ns,monitors:$monitors,
      gamescope_client:(if ($clients|type)=="array" then (first($clients[]|select(.pid==$verified_pid)) // null) else null end),
      gamescope_property:{address:$address,pid:$verified_pid,immediate:$immediate},
      launch:{skyrim_pid:$skyrim_pid},monitor_topology:$topology,
      hypr_options:{vfr:$vfr,allow_tearing:$allow_tearing},activewindow:$active}' \
      >> "$run_dir/hypr-state.ndjson" 2>/dev/null || true
}

trace_worker() {
  local run_id=$1 run_dir interval tick=0 timestamp uptime hypr_pid gamescope_pid xwayland_pid skyrim_pid
  local mem pressure_cpu pressure_memory pressure_io gpu_freq gpu_requested gpu_path gpu_root sysfile sysvalue
  local launch_pair address="" game_seen=false active status launch_timeout
  load_prepared "$run_id"
  [[ $RUN_KIND == presentation ]] || die "automatic trace is only defined for presentation runs"
  run_dir=$RUNS_DIR/$run_id
  interval=${SKYRIM_BENCHMARK_SAMPLE_INTERVAL:-0.25}
  launch_timeout=${SKYRIM_BENCHMARK_LAUNCH_TIMEOUT:-120}
  SECONDS=0
  TRACE_STATUS_FILE=$run_dir/trace-status
  printf 'running\n' > "$TRACE_STATUS_FILE"
  trap 'trace_worker_exit "$?"' EXIT
  printf 'timestamp_ns\tuptime_s\tmem_available_kb\tswap_used_kb\tsunreclaim_kb\tdirty_kb\twriteback_kb\tcpu_pressure\tmemory_pressure\tio_pressure\tgpu_freq_mhz\tgpu_requested_mhz\thypr_pid\thypr_start\thypr_utime\thypr_stime\thypr_rss\thypr_threads\thypr_read\thypr_write\thypr_fds\tgamescope_pid\tgamescope_start\tgamescope_utime\tgamescope_stime\tgamescope_rss\tgamescope_threads\tgamescope_read\tgamescope_write\tgamescope_fds\txwayland_pid\txwayland_start\txwayland_utime\txwayland_stime\txwayland_rss\txwayland_threads\txwayland_read\txwayland_write\txwayland_fds\tskyrim_pid\tskyrim_start\tskyrim_utime\tskyrim_stime\tskyrim_rss\tskyrim_threads\tskyrim_read\tskyrim_write\tskyrim_fds\n' > "$run_dir/samples.tsv"
  printf 'timestamp_ns\tpid\trole\texe\tcmdline\n' > "$run_dir/processes.tsv"
  printf 'timestamp_ns\tmetric\tvalue\n' > "$run_dir/gpu-state.tsv"
  gpu_path=$(printf '%s\n' /sys/class/drm/card*/gt/gt0/rps_cur_freq_mhz | head -n 1)
  gpu_root=$(dirname -- "$gpu_path")
  while [[ ! -f $run_dir/trace-stop ]]; do
    [[ -f $ACTIVE_FILE ]] || break
    read -r active < "$ACTIVE_FILE" || break
    [[ $active == "$run_id" ]] || break
    status=$(<"$run_dir/status")
    [[ $status == launched ]] || break
    if [[ $game_seen == false && $SECONDS -ge $launch_timeout ]]; then
      printf 'Skyrim was not observed within %ss\n' "$launch_timeout" >> "$run_dir/trace-worker.log"
      break
    fi
    timestamp=$(date +%s%N)
    read -r uptime _ < /proc/uptime
    if (( tick % 4 == 0 )); then
      hypr_pid=$(find_role_pid hyprland || true)
      if launch_pair=$(find_launch_processes); then
        IFS=$'\t' read -r skyrim_pid gamescope_pid <<< "$launch_pair"
        game_seen=true
      elif [[ $game_seen == true ]]; then
        break
      else
        skyrim_pid=""
        gamescope_pid=""
      fi
      if [[ $GAMESCOPE_MODE == enabled && -n $gamescope_pid ]]; then
        xwayland_pid=$(find_nested_xwayland "$gamescope_pid" || true)
      else
        xwayland_pid=""
      fi
    fi
    record_process_once "$run_dir" hyprland "$hypr_pid"
    record_process_once "$run_dir" gamescope "$gamescope_pid"
    record_process_once "$run_dir" xwayland "$xwayland_pid"
    record_process_once "$run_dir" skyrim "$skyrim_pid"
    mem=$(awk '
      /^MemAvailable:/ {a=$2} /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2}
      /^SUnreclaim:/ {su=$2} /^Dirty:/ {d=$2} /^Writeback:/ {w=$2}
      END {printf "%s\\t%s\\t%s\\t%s\\t%s",a,st-sf,su,d,w}
    ' /proc/meminfo)
    pressure_cpu=$(awk '/^some/ {for(i=1;i<=NF;i++) if($i~/^avg10=/){sub(/^avg10=/,"");print $i}}' /proc/pressure/cpu)
    pressure_memory=$(awk '/^some/ {for(i=1;i<=NF;i++) if($i~/^avg10=/){sub(/^avg10=/,"");print $i}}' /proc/pressure/memory)
    pressure_io=$(awk '/^some/ {for(i=1;i<=NF;i++) if($i~/^avg10=/){sub(/^avg10=/,"");print $i}}' /proc/pressure/io)
    gpu_freq=NA
    gpu_requested=NA
    [[ -r $gpu_path ]] && read -r gpu_freq < "$gpu_path"
    [[ -r $gpu_root/punit_req_freq_mhz ]] && read -r gpu_requested < "$gpu_root/punit_req_freq_mhz"
    {
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t' "$timestamp" "$uptime" "$mem" \
        "${pressure_cpu:-NA}" "${pressure_memory:-NA}" "${pressure_io:-NA}" "$gpu_freq" "$gpu_requested"
      process_sample "$hypr_pid"; printf '\t'
      process_sample "$gamescope_pid"; printf '\t'
      process_sample "$xwayland_pid"; printf '\t'
      process_sample "$skyrim_pid"; printf '\n'
    } >> "$run_dir/samples.tsv"
    apply_and_verify_client_state "$run_dir" "$gamescope_pid" "$skyrim_pid"
    [[ -f $run_dir/client-verification.tsv ]] && \
      address=$(evidence_value "$run_dir/client-verification.tsv" address)
    if (( tick % 4 == 0 )); then
      sample_hypr_state "$run_dir" "$timestamp" "${gamescope_pid:-0}" "${skyrim_pid:-0}" "$address"
      for sysfile in "$gpu_root"/rps_*_freq_mhz "$gpu_root"/punit_req_freq_mhz \
        "$gpu_root"/rc6_residency_ms "$gpu_root"/throttle_reason_*; do
        [[ -r $sysfile ]] || continue
        read -r sysvalue < "$sysfile"
        printf '%s\t%s\t%s\n' "$timestamp" "${sysfile##*/}" "$sysvalue" >> "$run_dir/gpu-state.tsv"
      done
    fi
    ((tick+=1))
    sleep "$interval"
  done
}

start_trace() {
  local run_id=$1 run_dir pid
  run_dir=$RUNS_DIR/$run_id
  rm -f -- "$run_dir/trace-stop"
  printf 'timestamp_ns\tuptime_s\taction\tscope\tactive_class\tactive_title\n' > "$run_dir/events.tsv"
  save_journal_cursor user "$run_dir/user-journal.cursor"
  save_journal_cursor kernel "$run_dir/kernel-journal.cursor"
  nohup "$SCRIPT_PATH" trace-worker "$run_id" </dev/null >> "$run_dir/trace-worker.log" 2>&1 &
  pid=$!
  printf '%s\n' "$pid" > "$run_dir/trace-worker.pid"
  local _
  for _ in {1..20}; do
    [[ -f $run_dir/trace-status ]] && return
    kill -0 "$pid" 2>/dev/null || die "automatic trace worker exited during startup"
    sleep 0.05
  done
  die "automatic trace worker did not start"
}

trace_duration() {
  local samples=$1
  trace_metrics "$samples" | awk -F '\t' '{print $1}'
}

trace_metrics() {
  local samples=$1
  awk -F '\t' -v nominal="$TRACE_NOMINAL_INTERVAL" 'NR>1 {
    if ($2 !~ /^[0-9]+([.][0-9]+)?$/) {invalid++; next}
    uptime=$2+0
    count++
    if (count==1) first=uptime
    if (count>1) {
      gap=uptime-previous
      if (gap<=0) invalid++
      if (gap>max_gap) max_gap=gap
    }
    previous=uptime
    last=uptime
  }
  END {
    duration=(count>1 ? last-first : 0)
    density=(duration>0 ? (count-1)/duration : 0)
    coverage=(nominal>0 ? density*nominal : 0)
    if (coverage>1) coverage=1
    printf "%.3f\t%d\t%.6f\t%.6f\t%.6f\t%d\n",
      duration,count,max_gap+0,density,coverage,invalid+0
  }' "$samples"
}

aggregate_journals() {
  local run_dir=$1 duration=${2:-0} cursor
  printf 'source\tcategory\tcount\trate_per_second\n' > "$run_dir/journal-counts.tsv"
  : > "$run_dir/journal-evidence.txt"
  if [[ -f $run_dir/user-journal.cursor ]]; then
    read -r cursor < "$run_dir/user-journal.cursor"
    if [[ $cursor != unavailable* ]]; then
      journalctl --user --after-cursor="$cursor" --no-pager -o cat 2>/dev/null | awk -v duration="$duration" '
        /xwm: got the same buffer committed twice/ {duplicate++}
        /Compositor released us but we were not acquired/ {released++}
        /\[gamescope\].*(Error|error)/ {errors++}
        END {d=(duration>0?duration:1);
          print "user\tduplicate-buffer\t" duplicate+0 "\t" (duplicate+0)/d;
          print "user\txdg-release-without-acquire\t" released+0 "\t" (released+0)/d;
          print "user\tgamescope-error\t" errors+0 "\t" (errors+0)/d}
      ' >> "$run_dir/journal-counts.tsv" || true
      journalctl --user --after-cursor="$cursor" _COMM=Hyprland --no-pager -o json 2>/dev/null | \
        jq -r '.MESSAGE // empty' | awk -v duration="$duration" '
          /[Ww]arn|[Ee]rror|[Ff]ail/ {events++}
          END {d=(duration>0?duration:1);
            print "user\thyprland-warning-error\t" events+0 "\t" (events+0)/d}
        ' >> "$run_dir/journal-counts.tsv" || true
      journalctl --user --after-cursor="$cursor" --no-pager -o cat 2>/dev/null | awk '
        /\[gamescope\]|xwm:|xdg_backend/ {
          normalized=$0; gsub(/[0-9]+/, "#", normalized)
          if (!seen[normalized]++ && count++ < 100) print "user: " $0
        }
      ' >> "$run_dir/journal-evidence.txt" || true
      journalctl --user --after-cursor="$cursor" _COMM=Hyprland --no-pager -o json 2>/dev/null | \
        jq -r '.MESSAGE // empty' | awk '
          { normalized=$0; gsub(/[0-9]+/, "#", normalized) }
          !seen[normalized]++ && count++ < 100 {print "hyprland: " $0}
        ' >> "$run_dir/journal-evidence.txt" || true
    fi
  fi
  if [[ -f $run_dir/kernel-journal.cursor ]]; then
    read -r cursor < "$run_dir/kernel-journal.cursor"
    if [[ $cursor != unavailable* ]]; then
      journalctl -k --after-cursor="$cursor" --no-pager -o cat 2>/dev/null | awk -v duration="$duration" '
        { line=tolower($0) }
        line ~ /i915|drm|gpu hang|reset|usb|hid|oom|thermal/ {events++}
        END {d=(duration>0?duration:1);
          print "kernel\tgpu-input-oom-thermal\t" events+0 "\t" (events+0)/d}
      ' >> "$run_dir/journal-counts.tsv" || true
      journalctl -k --after-cursor="$cursor" --no-pager -o cat 2>/dev/null | awk '
        { line=tolower($0) }
        line ~ /i915|drm|gpu hang|reset|usb|hid|oom|thermal/ {
          normalized=line; gsub(/[0-9]+/, "#", normalized)
          if (!seen[normalized]++ && count++ < 100) print "kernel: " $0
        }
      ' >> "$run_dir/journal-evidence.txt" || true
    fi
  fi
}

stop_trace() {
  local run_id=$1 run_dir pid="" duration _ trace_state=unknown cmdline=""
  local sample_count max_gap density coverage invalid_samples
  run_dir=$RUNS_DIR/$run_id
  touch "$run_dir/trace-stop"
  [[ -f $run_dir/trace-worker.pid ]] && read -r pid < "$run_dir/trace-worker.pid"
  if [[ -n $pid ]]; then
    for _ in {1..50}; do
      [[ -f $run_dir/trace-status && $(<"$run_dir/trace-status") == stopped ]] && break
      [[ -r /proc/$pid/cmdline ]] || break
      cmdline=$(tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline" || true)
      [[ " $cmdline " == *" $SCRIPT_PATH trace-worker $run_id "* ]] || break
      sleep 0.1
    done
    if [[ ! -f $run_dir/trace-status || $(<"$run_dir/trace-status") != stopped ]] && \
       [[ -r /proc/$pid/cmdline ]] && \
       [[ " $(tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline" || true) " == *" $SCRIPT_PATH trace-worker $run_id "* ]]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      trace_state=forced-stopped
    fi
  fi
  rm -f -- "$run_dir/trace-worker.pid"
  if [[ $trace_state != forced-stopped && -f $run_dir/trace-status ]]; then
    trace_state=$(<"$run_dir/trace-status")
  fi
  if [[ $trace_state != stopped ]]; then
    [[ $trace_state == forced-stopped ]] || trace_state=failed
    printf '%s\n' "$trace_state" > "$run_dir/trace-status"
  fi
  read -r duration sample_count max_gap density coverage invalid_samples \
    < <(trace_metrics "$run_dir/samples.tsv")
  jq -n --arg duration "$duration" --argjson sample_count "$sample_count" \
    --arg max_gap "$max_gap" --arg density "$density" --arg coverage "$coverage" \
    --argjson invalid_samples "$invalid_samples" --arg nominal "$TRACE_NOMINAL_INTERVAL" \
    --arg max_allowed_gap "$TRACE_MAX_GAP" --arg min_density "$TRACE_MIN_DENSITY" \
    --arg stopped_at "$(date --iso-8601=seconds)" \
    '{schema:2,duration_seconds:($duration|tonumber),sample_count:$sample_count,
      maximum_sample_gap_seconds:($max_gap|tonumber),sample_density_hz:($density|tonumber),
      nominal_coverage_ratio:($coverage|tonumber),invalid_sample_count:$invalid_samples,
      thresholds:{nominal_interval_seconds:($nominal|tonumber),
        maximum_gap_seconds:($max_allowed_gap|tonumber),minimum_density_hz:($min_density|tonumber)},
      stopped_at:$stopped_at}' > "$run_dir/trace-summary.json"
  aggregate_journals "$run_dir" "$duration"
}

evidence_value() {
  local file=$1 key=$2
  awk -F '\t' -v key="$key" '$1 == key {print $2; exit}' "$file"
}

write_runtime_verification() {
  local run_id=$1 run_dir pass=true errors="" value cmdline expected
  local hypr_seen gamescope_seen xwayland_seen skyrim_seen monitor_valid hypr_options_valid tearing_seen property_tied
  local topology_valid=false ini_valid=true duration=0 sample_count=0 max_gap=0 density=0 coverage=0 invalid_samples=0
  local controlled_pid=0 controlled_address=""
  local prefs_expected=unavailable prefs_current=unavailable skyrim_expected=unavailable skyrim_current=unavailable
  local prefs_path skyrim_path
  run_dir=$RUNS_DIR/$run_id
  load_prepared "$run_id"
  [[ $RUN_KIND == presentation ]] || return 0
  if [[ ! -f $run_dir/trace-status || $(<"$run_dir/trace-status") != stopped ]]; then
    pass=false; errors+="automatic trace did not stop cleanly; "
  fi
  if [[ ! -s $run_dir/samples.tsv || $(wc -l < "$run_dir/samples.tsv") -lt 2 ]]; then
    pass=false; errors+="automatic trace has no samples; "
  else
    read -r duration sample_count max_gap density coverage invalid_samples \
      < <(trace_metrics "$run_dir/samples.tsv")
    (( sample_count >= 2 )) || { pass=false; errors+="automatic trace has fewer than two samples; "; }
    (( invalid_samples == 0 )) || { pass=false; errors+="automatic trace has invalid or non-monotonic samples; "; }
    awk -v actual="$max_gap" -v limit="$TRACE_MAX_GAP" 'BEGIN {exit !(actual<=limit)}' \
      || { pass=false; errors+="automatic trace sample gap exceeds ${TRACE_MAX_GAP}s; "; }
    awk -v actual="$density" -v minimum="$TRACE_MIN_DENSITY" 'BEGIN {exit !(actual>=minimum)}' \
      || { pass=false; errors+="automatic trace density is below ${TRACE_MIN_DENSITY}Hz; "; }
    read -r hypr_seen gamescope_seen xwayland_seen skyrim_seen < <(awk -F '\t' 'NR>1 {
      if ($13+0>0) h=1; if ($22+0>0) g=1; if ($31+0>0) x=1; if ($40+0>0) s=1
    } END {print h+0,g+0,x+0,s+0}' "$run_dir/samples.tsv")
    (( hypr_seen == 1 )) || { pass=false; errors+="Hyprland process was not sampled; "; }
    (( skyrim_seen == 1 )) || { pass=false; errors+="Skyrim process was not sampled; "; }
    grep -q $'\thyprland\t' "$run_dir/processes.tsv" 2>/dev/null \
      || { pass=false; errors+="Hyprland process identity was not recorded; "; }
    grep -q $'\tskyrim\t' "$run_dir/processes.tsv" 2>/dev/null \
      || { pass=false; errors+="Skyrim process identity was not recorded; "; }
    if [[ $GAMESCOPE_MODE == enabled ]]; then
      (( gamescope_seen == 1 )) || { pass=false; errors+="verified gamescope process was not sampled; "; }
      (( xwayland_seen == 1 )) || { pass=false; errors+="nested Xwayland was not sampled; "; }
      grep -q $'\tgamescope\t' "$run_dir/processes.tsv" 2>/dev/null \
        || { pass=false; errors+="gamescope process identity was not recorded; "; }
      grep -q $'\txwayland\t' "$run_dir/processes.tsv" 2>/dev/null \
        || { pass=false; errors+="nested Xwayland identity was not recorded; "; }
    elif (( gamescope_seen != 0 )); then
      pass=false; errors+="gamescope appeared during bypass; "
    elif grep -q $'\tgamescope\t' "$run_dir/processes.tsv" 2>/dev/null; then
      pass=false; errors+="gamescope process identity appeared during bypass; "
    fi
  fi
  if [[ ! -s $run_dir/hypr-state.ndjson ]]; then
    pass=false; errors+="Hyprland state trace is empty; "
  else
    monitor_valid=$(jq -s --arg connector "$CONNECTOR" --argjson width "$OUTPUT_WIDTH" \
      --argjson height "$OUTPUT_HEIGHT" --argjson refresh "$REFRESH_HZ" 'any(.[].monitors[]?;
        .name==$connector and .width==$width and .height==$height and
        (.refreshRate|round)==$refresh and .focused==true)' "$run_dir/hypr-state.ndjson")
    [[ $monitor_valid == true ]] || { pass=false; errors+="prepared monitor was not observed; "; }
    topology_valid=$(jq -s --slurpfile prepared "$run_dir/prepared-monitor-topology.json" '
      length>0 and all(.[]; .monitor_topology==$prepared[0])' "$run_dir/hypr-state.ndjson")
    [[ $topology_valid == true ]] || { pass=false; errors+="enabled monitor topology drifted during trace; "; }
    hypr_options_valid=$(jq -s --arg mode "$GAMESCOPE_MODE" \
      --argjson vfr "$HYPR_VFR" --argjson tearing "$HYPR_ALLOW_TEARING" '
      (if $mode=="enabled" then
        (map((.gamescope_property.pid? // 0)>0)|index(true))
       else (map((.launch.skyrim_pid? // 0)>0)|index(true)) end) as $start
      | ($start!=null) and all(.[$start:][];
          .hypr_options.vfr==$vfr and .hypr_options.allow_tearing==$tearing)' \
      "$run_dir/hypr-state.ndjson")
    [[ $hypr_options_valid == true ]] || { pass=false; errors+="Hyprland options drifted during run; "; }
    if [[ $HYPR_ALLOW_TEARING == false ]]; then
      tearing_seen=$(jq -s 'any(.[].monitors[]?; .activelyTearing==true)' "$run_dir/hypr-state.ndjson")
      [[ $tearing_seen == false ]] || { pass=false; errors+="monitor actively tore with tearing disabled; "; }
    fi
    if [[ $GAMESCOPE_MODE == enabled && -f $run_dir/client-verification.tsv ]]; then
      controlled_address=$(evidence_value "$run_dir/client-verification.tsv" address)
      controlled_pid=$(evidence_value "$run_dir/client-verification.tsv" pid)
      property_tied=$(jq -s --arg address "$controlled_address" --argjson pid "$controlled_pid" \
        --argjson immediate "$HYPR_IMMEDIATE" '
        (map((.gamescope_property.pid? // 0)>0)|index(true)) as $start
        | ($start!=null) and all(.[$start:][];
          .gamescope_property.address==$address and .gamescope_property.pid==$pid and
          .gamescope_property.immediate==$immediate and .gamescope_client!=null and
          .gamescope_client.pid==$pid and .gamescope_client.address==$address)' \
        "$run_dir/hypr-state.ndjson")
      [[ $property_tied == true ]] \
        || { pass=false; errors+="gamescope PID/address/immediate state drifted after discovery; "; }
    fi
  fi
  if [[ $GAMESCOPE_MODE == enabled ]]; then
    if [[ ! -f $run_dir/client-verification.tsv ]]; then
      pass=false; errors+="gamescope client was not verified; "
    else
      value=$(evidence_value "$run_dir/client-verification.tsv" actual_immediate)
      [[ $value == "$HYPR_IMMEDIATE" ]] || { pass=false; errors+="immediate mismatch; "; }
      value=$(evidence_value "$run_dir/client-verification.tsv" actual_binary)
      [[ $value == "$GAMESCOPE_BIN" ]] || { pass=false; errors+="gamescope binary mismatch; "; }
      cmdline=$(evidence_value "$run_dir/client-verification.tsv" cmdline)
      expected=" $GAMESCOPE_ARGS -- "
      [[ " $cmdline " == *"$expected"* ]] || { pass=false; errors+="gamescope arguments/backend mismatch; "; }
    fi
  fi
  if [[ ! -f $run_dir/overlay-verification.tsv ]]; then
    pass=false; errors+="overlay ownership was not verified; "
  else
    value=$(evidence_value "$run_dir/overlay-verification.tsv" actual_gamescope_overlay)
    [[ $value == false ]] || { pass=false; errors+="overlay loaded into gamescope; "; }
    value=$(evidence_value "$run_dir/overlay-verification.tsv" actual_game_overlay)
    if [[ $OVERLAY_POLICY == game ]]; then
      [[ $value == true ]] || { pass=false; errors+="game overlay missing; "; }
    else
      [[ $value == false ]] || { pass=false; errors+="game overlay present under off policy; "; }
    fi
  fi
  if ! verify_frozen_inis "$run_dir"; then
    ini_valid=false
    pass=false; errors+="generated Skyrim INI content drifted after activation; "
  fi
  if [[ -f $run_dir/activated-ini-hashes.tsv ]]; then
    prefs_expected=$(awk -F '\t' '$1=="SkyrimPrefs.ini" {print $2; exit}' "$run_dir/activated-ini-hashes.tsv")
    skyrim_expected=$(awk -F '\t' '$1=="Skyrim.ini" {print $2; exit}' "$run_dir/activated-ini-hashes.tsv")
  fi
  prefs_path=$(prefs_ini_path)
  skyrim_path=$(skyrim_ini_path)
  [[ -f $prefs_path ]] && prefs_current=$(sha256sum -- "$prefs_path" | awk '{print $1}')
  [[ -f $skyrim_path ]] && skyrim_current=$(sha256sum -- "$skyrim_path" | awk '{print $1}')
  errors=${errors%; }
  jq -n --argjson passed "$pass" --arg errors "$errors" \
    --arg mode "$GAMESCOPE_MODE" --arg backend "$GAMESCOPE_BACKEND" \
    --arg overlay "$OVERLAY_POLICY" --arg immediate "$HYPR_IMMEDIATE" \
    --arg controlled_address "$controlled_address" --argjson controlled_pid "$controlled_pid" \
    --arg duration "$duration" --argjson sample_count "$sample_count" --arg max_gap "$max_gap" \
    --arg density "$density" --arg coverage "$coverage" --argjson invalid_samples "$invalid_samples" \
    --argjson topology_valid "$topology_valid" --argjson ini_valid "$ini_valid" \
    --arg topology_hash "$MONITOR_TOPOLOGY_HASH" --arg prefs_expected "$prefs_expected" \
    --arg prefs_current "$prefs_current" --arg skyrim_expected "$skyrim_expected" \
    --arg skyrim_current "$skyrim_current" \
    '{schema:2,passed:$passed,errors:$errors,gamescope_mode:$mode,backend:$backend,
      overlay_policy:$overlay,client_immediate:($immediate=="true"),
      controlled_client:{pid:$controlled_pid,address:$controlled_address},
      trace:{duration_seconds:($duration|tonumber),sample_count:$sample_count,
        maximum_sample_gap_seconds:($max_gap|tonumber),sample_density_hz:($density|tonumber),
        nominal_coverage_ratio:($coverage|tonumber),invalid_sample_count:$invalid_samples},
      monitor_topology_valid:$topology_valid,monitor_topology_sha256:$topology_hash,
      generated_inis_valid:$ini_valid,
      generated_inis:{skyrim_prefs:{expected_sha256:$prefs_expected,current_sha256:$prefs_current},
        skyrim:{expected_sha256:$skyrim_expected,current_sha256:$skyrim_current}},
      verified_at:(now|todateiso8601)}' \
    > "$run_dir/runtime-verification.json"
}

mark_event() {
  local action=$1
  shift
  local scope="" run_id run_dir timestamp uptime active class title
  [[ $action == stall-recovered ]] || die "mark action must be stall-recovered"
  while (( $# > 0 )); do
    case $1 in
      --scope) scope=${2:?missing scope}; shift 2 ;;
      *) die "unknown mark option: $1" ;;
    esac
  done
  [[ -z $scope || $scope == game || $scope == desktop ]] || die "--scope must be game or desktop"
  [[ -f $ACTIVE_FILE ]] || die "no presentation run is active"
  run_id=$(<"$ACTIVE_FILE")
  load_prepared "$run_id"
  [[ $RUN_KIND == presentation ]] || die "event markers require a presentation run"
  run_dir=$RUNS_DIR/$run_id
  timestamp=$(date +%s%N)
  read -r uptime _ < /proc/uptime
  active=$(hyprctl -j activewindow 2>/dev/null || printf '{}')
  class=$(jq -r '.class // "unknown"' <<< "$active")
  title=$(jq -r '.title // "unknown"' <<< "$active")
  if [[ -z $scope ]]; then
    if [[ ${class,,} == *gamescope* || ${class,,} == *skyrim* ]]; then
      scope=game
    else
      scope=desktop
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$timestamp" "$uptime" "$action" "$scope" \
    "$(sanitize_cell "$class")" "$(sanitize_cell "$title")" >> "$run_dir/events.tsv"
  printf 'RUN=%s\nMARK=%s\nSCOPE=%s\nTIMESTAMP_NS=%s\n' "$run_id" "$action" "$scope" "$timestamp"
}

activate_run() {
  local requested=$1 launch_args=$2 armed run_dir
  [[ -f $ARMED_FILE ]] || die "no run is armed"
  armed=$(<"$ARMED_FILE")
  [[ $requested == "$armed" ]] || die "requested run $requested does not match armed run $armed"
  verify_prepared "$requested"
  if [[ $RUN_KIND == presentation && $(boot_gate_state) != READY ]]; then
    die "run $requested requires a reboot after queueing"
  fi
  verify_launch_args "$launch_args"
  verify_generated_prefs
  run_dir=$RUNS_DIR/$requested
  if [[ $RUN_KIND == presentation ]]; then
    trap 'trap - EXIT ERR INT TERM; restore_runtime_hypr "$requested"' EXIT ERR INT TERM
    apply_runtime_hypr "$run_dir"
    freeze_generated_inis "$run_dir"
  fi
  config_hashes > "$run_dir/actual-config-hashes.tsv"
  focused_monitor > "$run_dir/actual-monitor.json"
  normalized_monitor_topology | jq . > "$run_dir/actual-monitor-topology.json"
  cmp -s -- "$run_dir/prepared-monitor-topology.json" "$run_dir/actual-monitor-topology.json" \
    || die "enabled monitor topology changed during activation"
  jq -n --arg run_id "$requested" --arg kind "$RUN_KIND" --arg profile "$PROFILE" --arg args "$launch_args" \
    --arg build_id "$STEAM_BUILD_ID" --arg config_hash "$CONFIG_HASH" \
    --arg topology_hash "$MONITOR_TOPOLOGY_HASH" --arg prefs_hash "$PREFS_INI_HASH" \
    --arg skyrim_ini_hash "$SKYRIM_INI_HASH" \
    --argjson game_width "$GAME_WIDTH" --argjson game_height "$GAME_HEIGHT" \
    --argjson output_width "$OUTPUT_WIDTH" --argjson output_height "$OUTPUT_HEIGHT" \
    '{schema:2, run_id:$run_id, kind:$kind, state:"launched", profile:$profile, gamescope_args:$args,
      game:{width:$game_width,height:$game_height},
      output:{width:$output_width,height:$output_height,topology_sha256:$topology_hash},
      generated_inis:{skyrim_prefs_sha256:$prefs_hash,skyrim_sha256:$skyrim_ini_hash},
      hud:true, steam_build_id:$build_id, config_hash:$config_hash, activated_at:(now | todateiso8601)}' \
    > "$run_dir/actual.json"
  mv -- "$ARMED_FILE" "$ACTIVE_FILE"
  write_state "$requested" launched
  update_run_status "$requested" launched
  if [[ $RUN_KIND == presentation ]]; then
    start_trace "$requested"
    trap - EXIT ERR INT TERM
  fi
}

post_launch() {
  local run_id=$1 active run_dir scope_log
  [[ -f $ACTIVE_FILE ]] || return 0
  active=$(<"$ACTIVE_FILE")
  [[ $active == "$run_id" ]] || die "active run is $active, not $run_id"
  run_dir=$RUNS_DIR/$run_id
  load_prepared "$run_id"
  if [[ $RUN_KIND == presentation ]]; then
    trap 'trap - EXIT ERR INT TERM; restore_runtime_hypr "$run_id"' EXIT ERR INT TERM
    stop_trace "$run_id"
    write_runtime_verification "$run_id"
    restore_runtime_hypr "$run_id"
    trap - EXIT ERR INT TERM
  fi
  scope_log=${SKYRIM_BENCHMARK_SCOPE_LOG:-$HOME/.config/scopebuddy/scopebuddy.log}
  if [[ -f $scope_log ]]; then
    cp -- "$scope_log" "$run_dir/scopebuddy.log"
  fi
  date --iso-8601=seconds > "$run_dir/process-ended-at"
  write_state "$run_id" awaiting-observation
  update_run_status "$run_id" awaiting-observation
}

latest_summary() {
  local run_dir=$1 summary latest=""
  for summary in "$run_dir"/*_summary.csv; do
    [[ -f $summary ]] || continue
    if [[ -z $latest || $summary -nt $latest ]]; then
      latest=$summary
    fi
  done
  [[ -n $latest ]] || return 1
  printf '%s\n' "$latest"
}

classify_events() {
  local run_dir=$1 event_epoch event_uptime action scope _ _ raw end_epoch_ns end_uptime last_elapsed target result
  local inside max_frame max_gap classification chosen_target chosen_frame chosen_gap chosen_class chosen_recording
  local output=$run_dir/event-classifications.tsv
  local -a recordings=()
  printf 'timestamp_ns\taction\tscope\ttarget_elapsed_ns\tmax_frametime_ms\tmax_sample_gap_ms\tclassification\trecording\n' > "$output"
  [[ -f $run_dir/events.tsv ]] || return 0
  for raw in "$run_dir"/*.csv; do
    [[ -f $raw && $raw != *_summary.csv ]] && recordings+=("$raw")
  done
  while IFS=$'\t' read -r event_epoch event_uptime action scope _ _; do
    [[ $event_epoch == timestamp_ns || $action != stall-recovered ]] && continue
    chosen_target=NA; chosen_frame=NA; chosen_gap=NA; chosen_class=ambiguous; chosen_recording=none
    for raw in "${recordings[@]}"; do
      end_epoch_ns=$(date -d "$(stat -c %y "$raw")" +%s%N)
      last_elapsed=$(awk -F, 'NR > 3 {last=$NF} END {print last+0}' "$raw")
      end_uptime=$(awk -F '\t' -v target="$end_epoch_ns" 'NR>1 {
        diff=$1-target; if (diff<0) diff=-diff
        if (!seen || diff<best) {best=diff; uptime=$2; seen=1}
      } END {if (seen) print uptime}' "$run_dir/samples.tsv")
      if [[ -n $end_uptime ]]; then
        target=$(awk -v last="$last_elapsed" -v event="$event_uptime" -v end="$end_uptime" \
          'BEGIN {printf "%.0f", last + (event-end)*1000000000}')
      else
        target=$(( last_elapsed - (end_epoch_ns - event_epoch) ))
      fi
      result=$(awk -F, -v target="$target" '
        NR == 3 {
          for (i=1; i<=NF; i++) {
            name=$i; gsub(/^"|"$/, "", name)
            if (name == "frametime") fi=i
            if (name == "elapsed") ei=i
          }
          next
        }
        NR > 3 && fi && ei {
          elapsed=$ei+0; frame=$fi+0
          if (!seen) {first=elapsed; seen=1}
          last=elapsed
          if (elapsed >= target-5000000000 && elapsed <= target+2000000000) {
            window_count++
            if (frame > max_frame) max_frame=frame
            if (previous && (elapsed-previous)/1000000 > max_gap) max_gap=(elapsed-previous)/1000000
          }
          previous=elapsed
        }
        END {
          if (!seen || target < first || target > last) {
            printf "0\tNA\tNA\tambiguous"; exit
          }
          if (window_count == 0) {
            printf "1\tNA\tNA\tambiguous"; exit
          }
          severity=(max_frame > max_gap ? max_frame : max_gap)
          if (severity >= 500) class="frame-freeze"
          else if (severity < 100) class="cursor/compositor-stall"
          else class="ambiguous"
          printf "1\t%.3f\t%.3f\t%s", max_frame+0, max_gap+0, class
        }
      ' "$raw")
      IFS=$'\t' read -r inside max_frame max_gap classification <<< "$result"
      if [[ $inside == 1 ]]; then
        chosen_target=$target; chosen_frame=$max_frame; chosen_gap=$max_gap
        chosen_class=$classification; chosen_recording=${raw##*/}
        break
      fi
    done
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$event_epoch" "$action" "$scope" \
      "$chosen_target" "$chosen_frame" "$chosen_gap" "$chosen_class" "$chosen_recording" >> "$output"
  done < "$run_dir/events.tsv"
}

complete_run() {
  local run_id=$1
  shift
  local cursor="" game_cursor="" desktop_cursor="" verdict="" notes="" active run_dir summary="" raw=""
  local p01=NA p1=NA avg=NA mango_duration=0 instrumentation target trace_seconds=0 stalls=0 runtime_pass=false
  local frame_freezes=0 cursor_stalls=0 ambiguous_stalls=0 sample_count=0 max_gap=0 density=0 coverage=0
  local invalid_samples=0 minimum_samples=0
  while (( $# > 0 )); do
    case $1 in
      --cursor) cursor=${2:?missing cursor value}; shift 2 ;;
      --game-cursor) game_cursor=${2:?missing game cursor value}; shift 2 ;;
      --desktop-cursor) desktop_cursor=${2:?missing desktop cursor value}; shift 2 ;;
      --verdict) verdict=${2:?missing verdict value}; shift 2 ;;
      --notes) notes=${2:?missing notes value}; shift 2 ;;
      *) die "unknown complete option: $1" ;;
    esac
  done
  [[ $verdict =~ ^(accepted|rejected|inconclusive)$ ]] || die "invalid --verdict"
  [[ -f $ACTIVE_FILE ]] || die "no run is awaiting completion"
  active=$(<"$ACTIVE_FILE")
  [[ $active == "$run_id" ]] || die "active run is $active, not $run_id"
  [[ $(<"$RUNS_DIR/$run_id/status") == awaiting-observation ]] || die "run $run_id is not awaiting observation"
  load_prepared "$run_id"
  run_dir=$RUNS_DIR/$run_id
  if [[ $RUN_KIND == presentation ]]; then
    [[ -z $cursor ]] || {
      [[ -z $game_cursor ]] && game_cursor=$cursor
      [[ -z $desktop_cursor ]] && desktop_cursor=$cursor
    }
    [[ $game_cursor =~ ^(good|bad|not-tested)$ ]] \
      || die "--game-cursor must be good, bad, or not-tested"
    [[ $desktop_cursor =~ ^(good|bad|not-tested)$ ]] \
      || die "--desktop-cursor must be good, bad, or not-tested"
    require_file "$run_dir/samples.tsv"
    [[ $(wc -l < "$run_dir/samples.tsv") -ge 2 ]] \
      || die "automatic trace contains no samples"
    [[ -f $run_dir/trace-status && $(<"$run_dir/trace-status") == stopped ]] \
      || die "automatic trace did not stop cleanly"
    read -r trace_seconds sample_count max_gap density coverage invalid_samples \
      < <(trace_metrics "$run_dir/samples.tsv")
    awk -v actual="$trace_seconds" 'BEGIN {exit !(actual>0)}' \
      || die "automatic trace has zero duration"
    (( sample_count >= 2 && invalid_samples == 0 )) \
      || die "automatic trace sample sequence is incomplete or non-monotonic"
    awk -v actual="$max_gap" -v limit="$TRACE_MAX_GAP" 'BEGIN {exit !(actual<=limit)}' \
      || die "automatic trace maximum sample gap ${max_gap}s exceeds ${TRACE_MAX_GAP}s"
    awk -v actual="$density" -v minimum="$TRACE_MIN_DENSITY" 'BEGIN {exit !(actual>=minimum)}' \
      || die "automatic trace density ${density}Hz is below ${TRACE_MIN_DENSITY}Hz"
    stalls=$(awk -F '\t' 'NR > 1 && $3 == "stall-recovered" {count++} END {print count+0}' \
      "$run_dir/events.tsv")
    [[ -f $run_dir/runtime-verification.json ]] && \
      runtime_pass=$(jq -r '.passed' "$run_dir/runtime-verification.json")
    [[ $runtime_pass == true ]] \
      || die "run failed runtime verification and must be invalidated"
    verify_frozen_topology "$run_dir"
    verify_frozen_inis "$run_dir" \
      || die "generated Skyrim INI content drifted after runtime verification; invalidate $run_id"
    if summary=$(latest_summary "$run_dir"); then
      IFS=, read -r p01 p1 _ avg _ < <(sed -n '2p' "$summary")
      raw=${summary%_summary.csv}.csv
      require_file "$raw"
      mango_duration=$(awk -F, 'FNR==4 { first=$NF } END { printf "%.1f", ($NF-first)/1000000000 }' "$raw")
    fi
    classify_events "$run_dir" "$raw"
    frame_freezes=$(awk -F '\t' 'NR>1 && $7=="frame-freeze" {n++} END {print n+0}' \
      "$run_dir/event-classifications.tsv")
    cursor_stalls=$(awk -F '\t' 'NR>1 && $7=="cursor/compositor-stall" {n++} END {print n+0}' \
      "$run_dir/event-classifications.tsv")
    ambiguous_stalls=$(awk -F '\t' 'NR>1 && $7=="ambiguous" {n++} END {print n+0}' \
      "$run_dir/event-classifications.tsv")
    if [[ $verdict == accepted ]]; then
      [[ $game_cursor == good && $desktop_cursor == good ]] \
        || die "accepted presentation runs require good game and desktop cursor observations"
      (( stalls == 0 )) || die "accepted presentation runs cannot contain a stall marker"
      if [[ $REPETITION == soak ]]; then
        awk -v actual="$trace_seconds" -v target="$DURATION_SECONDS" \
          'BEGIN { exit !(actual >= target) }' \
          || die "soak trace lasted ${trace_seconds}s; expected at least ${DURATION_SECONDS}s"
        minimum_samples=$((DURATION_SECONDS * 2 + 1))
        (( sample_count >= minimum_samples )) \
          || die "soak trace has $sample_count samples; expected at least $minimum_samples at >=2Hz"
      else
        [[ -n $summary ]] || die "accepted short run has no MangoHud recording"
        target=$DURATION_SECONDS
        awk -v actual="$mango_duration" -v target="$target" \
          'BEGIN { exit !(actual >= target-10 && actual <= target+10) }' \
          || die "recording lasted ${mango_duration}s; expected ${target}s ±10s"
        local minimum_trace=$((WARMUP_SECONDS + DURATION_SECONDS + 30 - 10))
        awk -v actual="$trace_seconds" -v target="$minimum_trace" \
          'BEGIN { exit !(actual >= target) }' \
          || die "automatic trace lasted ${trace_seconds}s; expected at least ${minimum_trace}s"
        minimum_samples=$((minimum_trace * 2 + 1))
        (( sample_count >= minimum_samples )) \
          || die "automatic trace has $sample_count samples; expected at least $minimum_samples at >=2Hz"
        verify_fps_nonregression "$run_id" "$avg" "$p1"
      fi
    elif [[ -z $summary && $game_cursor != bad && $desktop_cursor != bad ]]; then
      die "MangoHud may be omitted only for a reported cursor failure"
    fi
    if [[ -n $summary ]]; then
      instrumentation="automatic-trace-${trace_seconds}s+mangohud-${mango_duration}s"
    else
      instrumentation="automatic-trace-${trace_seconds}s+mangohud-not-recorded"
    fi
    notes=$(sanitize_cell "$notes")
    complete_presentation_row "$run_id" "$instrumentation" "$game_cursor" "$desktop_cursor" \
      "$stalls" "$avg" "$p1" "$p01" "$verdict" "$notes"
    jq -n --arg run_id "$run_id" --arg game_cursor "$game_cursor" \
      --arg desktop_cursor "$desktop_cursor" --arg verdict "$verdict" --arg notes "$notes" \
      --arg avg "$avg" --arg p1 "$p1" --arg p01 "$p01" --arg mango_duration "$mango_duration" \
      --arg trace_duration "$trace_seconds" --argjson sample_count "$sample_count" \
      --arg max_gap "$max_gap" --arg density "$density" --arg coverage "$coverage" \
      --argjson stalls "$stalls" --argjson runtime_verified "$runtime_pass" \
      --argjson frame_freezes "$frame_freezes" --argjson cursor_stalls "$cursor_stalls" \
      --argjson ambiguous_stalls "$ambiguous_stalls" \
      '{schema:2,run_id:$run_id,game_cursor:$game_cursor,desktop_cursor:$desktop_cursor,
        stall_count:$stalls,verdict:$verdict,notes:$notes,runtime_verified:$runtime_verified,
        stall_classification:{frame_freeze:$frame_freezes,cursor_compositor_stall:$cursor_stalls,
          ambiguous:$ambiguous_stalls},
        metrics:{average_fps:(if $avg=="NA" then null else ($avg|tonumber) end),
          p1_fps:(if $p1=="NA" then null else ($p1|tonumber) end),
          p01_fps:(if $p01=="NA" then null else ($p01|tonumber) end),
          mangohud_duration_seconds:($mango_duration|tonumber),trace_duration_seconds:($trace_duration|tonumber),
          trace_sample_count:$sample_count,maximum_trace_gap_seconds:($max_gap|tonumber),
          trace_density_hz:($density|tonumber),nominal_trace_coverage_ratio:($coverage|tonumber)},
        completed_at:(now|todateiso8601)}' > "$run_dir/observation.json"
    write_state "$run_id" completed
    restore_runtime_hypr "$run_id"
    rm -f -- "$ACTIVE_FILE"
    [[ $verdict == accepted ]] && promote_direct_replicate "$run_id"
    printf 'RUN=%s\nSTATE=completed\nVERDICT=%s\n' "$run_id" "$verdict"
    return
  fi

  [[ $cursor == good || $cursor == bad ]] || die "--cursor must be good or bad"
  summary=$(latest_summary "$run_dir") || die "no MangoHud summary found for $run_id"
  IFS=, read -r p01 p1 _ avg _ < <(sed -n '2p' "$summary")
  raw=${summary%_summary.csv}.csv
  require_file "$raw"
  mango_duration=$(awk -F, 'FNR==4 { first=$NF } END { printf "%.1f", ($NF-first)/1000000000 }' "$raw")
  target=$DURATION_SECONDS
  if [[ $cursor == good ]] && ! awk -v actual="$mango_duration" -v target="$target" 'BEGIN { exit !(actual >= target-10 && actual <= target+10) }'; then
    die "recording lasted ${mango_duration}s; expected ${target}s ±10s"
  fi
  instrumentation="recorded-${mango_duration}s"
  notes=$(sanitize_cell "$notes")
  complete_matrix_row "$run_id" "$instrumentation" "$cursor" "$avg" "$p1" "$p01" "$verdict" "$notes"
  jq -n --arg run_id "$run_id" --arg cursor "$cursor" --arg verdict "$verdict" \
    --arg notes "$notes" --arg avg "$avg" --arg p1 "$p1" --arg p01 "$p01" --arg duration "$mango_duration" \
    '{schema:1, run_id:$run_id, cursor:$cursor, verdict:$verdict, notes:$notes,
      metrics:{average_fps:($avg|tonumber),p1_fps:($p1|tonumber),p01_fps:($p01|tonumber),duration_seconds:($duration|tonumber)},
      completed_at:(now | todateiso8601)}' > "$run_dir/observation.json"
  write_state "$run_id" completed
  rm -f -- "$ACTIVE_FILE"
  printf 'RUN=%s\nSTATE=completed\nVERDICT=%s\n' "$run_id" "$verdict"
}

invalidate_run() {
  local run_id=$1 reason=$2 active="" armed=""
  reason=$(sanitize_cell "$reason")
  [[ -f $ARMED_FILE ]] && armed=$(<"$ARMED_FILE")
  [[ -f $ACTIVE_FILE ]] && active=$(<"$ACTIVE_FILE")
  [[ $run_id == "$armed" || $run_id == "$active" ]] || die "run $run_id is not armed or active"
  load_prepared "$run_id"
  if [[ $RUN_KIND == presentation && $run_id == "$active" ]]; then
    trap 'trap - EXIT ERR INT TERM; restore_runtime_hypr "$run_id"' EXIT ERR INT TERM
    if [[ -f $RUNS_DIR/$run_id/trace-worker.pid && ! -f $RUNS_DIR/$run_id/trace-stop ]]; then
      stop_trace "$run_id"
    fi
    restore_runtime_hypr "$run_id"
    trap - EXIT ERR INT TERM
  fi
  update_run_status "$run_id" invalid
  printf '%s\n' "$reason" > "$RUNS_DIR/$run_id/invalid-reason"
  write_state "$run_id" invalid
  [[ $run_id == "$armed" ]] && rm -f -- "$ARMED_FILE"
  [[ $run_id == "$active" ]] && rm -f -- "$ACTIVE_FILE"
  printf 'RUN=%s\nSTATE=invalid\nREASON=%s\n' "$run_id" "$reason"
}

cancel_run() {
  local run_id
  if [[ -f $ARMED_FILE ]]; then
    run_id=$(<"$ARMED_FILE")
  elif [[ -f $ACTIVE_FILE ]]; then
    run_id=$(<"$ACTIVE_FILE")
  else
    printf 'STATE=NO_ACTIVE_RUN\n'
    return
  fi
  invalidate_run "$run_id" "cancelled explicitly"
}

main() {
  require_file "$MATRIX_FILE"
  require_file "$PROFILES_FILE"
  case ${1:-status} in
    queue)
      [[ $# == 2 ]] || die "queue requires RUN_ID"
      queue_run "$2"
      ;;
    status)
      [[ $# == 1 ]] || die "status takes no arguments"
      status_command
      ;;
    profile)
      [[ $# == 2 ]] || die "profile requires PROFILE"
      print_profile "$2"
      ;;
    complete)
      [[ $# -ge 2 ]] || die "complete requires RUN_ID"
      run_id=$2
      shift 2
      complete_run "$run_id" "$@"
      ;;
    invalidate)
      [[ $# -ge 3 ]] || die "invalidate requires RUN_ID and REASON"
      run_id=$2
      shift 2
      invalidate_run "$run_id" "$*"
      ;;
    cancel|--cancel)
      cancel_run
      ;;
    activate)
      [[ $# == 3 ]] || die "activate requires RUN_ID and gamescope argument string"
      activate_run "$2" "$3"
      ;;
    post-launch)
      [[ $# == 2 ]] || die "post-launch requires RUN_ID"
      post_launch "$2"
      ;;
    mark)
      [[ $# -ge 2 ]] || die "mark requires an action"
      action=$2
      shift 2
      mark_event "$action" "$@"
      ;;
    trace-worker)
      [[ $# == 2 ]] || die "trace-worker requires RUN_ID"
      trace_worker "$2"
      ;;
    --help|-h|help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
