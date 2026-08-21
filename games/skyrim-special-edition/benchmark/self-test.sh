#!/usr/bin/env bash

set -euo pipefail

MODULE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONTROLLER=$MODULE_DIR/skyrim-benchmark.sh
TEST_ROOT=$(mktemp -d)
TEST_HOME=$TEST_ROOT/home
TEST_STATE=$TEST_ROOT/state
TEST_CONTROL=$TEST_ROOT/control
TEST_BIN=$TEST_ROOT/bin
TEST_GAMESCOPE_ROOT=$TEST_ROOT/gamescope/usr
TEST_GAMESCOPE_BIN=$TEST_GAMESCOPE_ROOT/bin/gamescope

cleanup() {
  local pid_file
  for pid_file in "$TEST_STATE"/skyrim-performance/runs/*/trace-worker.pid; do
    [[ -f $pid_file ]] || continue
    kill -CONT "$(<"$pid_file")" >/dev/null 2>&1 || true
    kill "$(<"$pid_file")" >/dev/null 2>&1 || true
  done
  if [[ ${SKYRIM_SELF_TEST_KEEP:-0} == 1 ]]; then
    printf 'benchmark self-test: kept fixtures at %s\n' "$TEST_ROOT" >&2
    return
  fi
  case $TEST_ROOT in
    /tmp/*) rm -rf -- "$TEST_ROOT" ;;
  esac
}
trap cleanup EXIT
trap 'status=$?; printf "benchmark self-test: line %s failed (%s): %s\n" "$LINENO" "$status" "$BASH_COMMAND" >&2' ERR

fail() {
  printf 'benchmark self-test: %s\n' "$*" >&2
  exit 1
}

expect_failure() {
  local label=$1
  shift
  if "$@" > "$TEST_ROOT/unexpected-success.out" 2> "$TEST_ROOT/expected-failure.err"; then
    fail "$label unexpectedly succeeded"
  fi
}

expect_failure_matching() {
  local label=$1 pattern=$2
  shift 2
  expect_failure "$label" "$@"
  grep -Eiq -- "$pattern" "$TEST_ROOT/expected-failure.err" \
    || fail "$label failed for the wrong reason: $(<"$TEST_ROOT/expected-failure.err")"
}

wait_for_file() {
  local path=$1 attempts=${2:-100}
  while (( attempts-- > 0 )); do
    [[ -s $path ]] && return 0
    sleep 0.02
  done
  fail "timed out waiting for $path"
}

wait_for_lines() {
  local path=$1 minimum=$2 attempts=${3:-100}
  while (( attempts-- > 0 )); do
    if [[ -f $path ]] && (( $(wc -l < "$path") >= minimum )); then
      return 0
    fi
    sleep 0.02
  done
  fail "timed out waiting for $minimum lines in $path"
}

wait_for_value() {
  local path=$1 expected=$2 attempts=${3:-100}
  while (( attempts-- > 0 )); do
    [[ -f $path && $(<"$path") == "$expected" ]] && return 0
    sleep 0.02
  done
  fail "timed out waiting for $path to contain $expected"
}

assert_ready() {
  local label=$1 receipt=$TEST_ROOT/status-$1.receipt
  "$CONTROLLER" status > "$receipt"
  grep -Fxq 'STATE=READY' "$receipt"
}

set_presentation_status() {
  local run_id=$1 status=$2 tmp=$SKYRIM_BENCHMARK_PRESENTATION_MATRIX.tmp
  awk -F '\t' -v OFS='\t' -v run_id="$run_id" -v status="$status" '
    $1 == run_id { $2=status }
    { print }
  ' "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX" > "$tmp"
  mv -- "$tmp" "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"
}

reset_presentation_run() {
  local run_id=$1 tmp=$SKYRIM_BENCHMARK_PRESENTATION_MATRIX.tmp
  awk -F '\t' -v OFS='\t' -v run_id="$run_id" '
    $1 == run_id {
      $2="planned"; $13="required"; $14="pending"; $15="pending"; $16="NA"
      $17="NA"; $18="NA"; $19="NA"; $20="pending"
    }
    { print }
  ' "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX" > "$tmp"
  mv -- "$tmp" "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"
}

write_mangohud_recording() {
  local run_dir=$1 duration_ns=${2:-120000000000}
  local average=${3:-56.0} p1=${4:-37.0} p01=${5:-25.0}
  printf '%s\n' \
    'os,cpu,gpu,ram,kernel,driver,cpuscheduler' \
    'test,test,test,0,test,test,test' \
    'fps,frametime,elapsed' \
    '60,16.6,0' \
    "60,16.6,$duration_ns" \
    > "$run_dir/mangohud.csv"
  printf '%s\n' \
    '0.1% Min FPS,1% Min FPS,97% Percentile FPS,Average FPS,GPU Load' \
    "$p01,$p1,70.0,$average,70.0" \
    > "$run_dir/mangohud_summary.csv"
}

write_classification_recording() {
  local run_dir=$1 end_epoch=1700000000000000000 first_epoch sample header
  first_epoch=$((end_epoch - 150000000000))
  header=$(head -n 1 "$run_dir/samples.tsv")
  sample=$(tail -n 1 "$run_dir/samples.tsv")
  {
    printf '%s\n' "$header"
    awk -F '\t' -v OFS='\t' -v first="$first_epoch" '
      {
        for (i=0; i<=840; i++) {
          $1=sprintf("%.0f",first+i*250000000)
          $2=sprintf("%.2f",850+i*0.25)
          print
        }
      }
    ' <<< "$sample"
  } > "$run_dir/samples.tsv.tmp"
  mv -- "$run_dir/samples.tsv.tmp" "$run_dir/samples.tsv"
  jq -n '{schema:1,duration_seconds:210,sample_count:841,
    maximum_gap_seconds:0.25,coverage_ratio:1,stopped_at:"fixture"}' \
    > "$run_dir/trace-summary.json"
  {
    printf '%s\n' \
      'os,cpu,gpu,ram,kernel,driver,cpuscheduler' \
      'test,test,test,0,test,test,test' \
      'fps,frametime,elapsed'
    awk 'BEGIN {
      for (i=0; i<=1200; i++) {
        elapsed=i*50000000
        frame=16
        if (elapsed==30000000000) frame=600
        if (elapsed==50000000000) frame=200
        printf "60,%s,%.0f\n",frame,elapsed
      }
    }'
  } > "$run_dir/classification.csv"
  touch -d '@1700000000.000000000' "$run_dir/classification.csv"
  printf '%s\n' \
    '0.1% Min FPS,1% Min FPS,97% Percentile FPS,Average FPS,GPU Load' \
    '25.0,37.0,70.0,56.0,70.0' \
    > "$run_dir/classification_summary.csv"
  printf '%s\n' \
    $'timestamp_ns\tuptime_s\taction\tscope\tactive_class\tactive_title' \
    $'1699999950000000000\t950\tstall-recovered\tgame\tgamescope\tSkyrim Special Edition' \
    $'1699999970000000000\t970\tstall-recovered\tgame\tgamescope\tSkyrim Special Edition' \
    $'1699999990000000000\t990\tstall-recovered\tdesktop\tkitty\tshell' \
    $'1699999930000000000\t930\tstall-recovered\tdesktop\tkitty\tshell' \
    > "$run_dir/events.tsv"
}

trace_fixture_template() {
  local run_dir=$1 row
  row=$(awk -F '\t' 'NR > 1 && $13+0 > 0 && $40+0 > 0 {line=$0} END {print line}' \
    "$run_dir/samples.tsv")
  [[ -n $row ]] || row=$(tail -n 1 "$run_dir/samples.tsv")
  [[ $row != timestamp_ns$'\t'* ]] || fail "trace fixture has no process sample"
  printf '%s\n' "$row"
}

write_gappy_trace_span() {
  local run_dir=$1 seconds=$2 header row first=1700000000000000000 target
  header=$(head -n 1 "$run_dir/samples.tsv")
  row=$(trace_fixture_template "$run_dir")
  target=$((first + seconds * 1000000000))
  {
    printf '%s\n' "$header"
    awk -F '\t' -v OFS='\t' -v timestamp="$first" '{$1=timestamp; $2=1000; print}' <<< "$row"
    awk -F '\t' -v OFS='\t' -v timestamp="$target" -v uptime="$((1000 + seconds))" \
      '{$1=timestamp; $2=uptime; print}' <<< "$row"
  } > "$run_dir/samples.tsv.tmp"
  mv -- "$run_dir/samples.tsv.tmp" "$run_dir/samples.tsv"
  jq -n --argjson duration "$seconds" \
    '{schema:1,duration_seconds:$duration,sample_count:2,
      maximum_gap_seconds:$duration,coverage_ratio:0,stopped_at:"fixture"}' \
    > "$run_dir/trace-summary.json"
}

write_dense_trace_span() {
  local run_dir=$1 seconds=$2 header row first=1700000000000000000 steps sample_count
  header=$(head -n 1 "$run_dir/samples.tsv")
  row=$(trace_fixture_template "$run_dir")
  steps=$((seconds * 4))
  sample_count=$((steps + 1))
  {
    printf '%s\n' "$header"
    awk -F '\t' -v OFS='\t' -v first="$first" -v steps="$steps" '
      {
        for (i=0; i<=steps; i++) {
          $1=sprintf("%.0f",first+i*250000000)
          $2=sprintf("%.2f",1000+i*0.25)
          print
        }
      }
    ' <<< "$row"
  } > "$run_dir/samples.tsv.tmp"
  mv -- "$run_dir/samples.tsv.tmp" "$run_dir/samples.tsv"
  jq -n --argjson duration "$seconds" --argjson samples "$sample_count" \
    '{schema:1,duration_seconds:$duration,sample_count:$samples,
      maximum_gap_seconds:0.25,coverage_ratio:1,stopped_at:"fixture"}' \
    > "$run_dir/trace-summary.json"
}

expect_all_completion_verdicts_refused() {
  local run_id=$1 pattern=$2 verdict
  for verdict in accepted rejected inconclusive; do
    expect_failure_matching \
      "$run_id $verdict completion" \
      "$pattern" \
      "$CONTROLLER" complete "$run_id" \
        --game-cursor good \
        --desktop-cursor good \
        --verdict "$verdict" \
        --notes "Synthetic $verdict refusal."
  done
}

append_runtime_drift_states() {
  local run_dir=$1 timestamp
  timestamp=$(date +%s%N)
  {
    jq -cn --argjson timestamp_ns "$((timestamp + 1))" '
      {timestamp_ns:$timestamp_ns,
       monitors:[
         {name:"DP-1",width:3440,height:1440,refreshRate:144,focused:true,activelyTearing:false},
         {name:"HDMI-A-2",width:1920,height:1080,refreshRate:60,focused:false,activelyTearing:false}],
       gamescope_client:{address:"0xabc",pid:102},
       gamescope_property:{address:"0xabc",pid:102,immediate:false},
       hypr_options:{vfr:false,allow_tearing:false},activewindow:{address:"0xabc",class:"gamescope"}}
    '
    jq -cn --argjson timestamp_ns "$((timestamp + 2))" '
      {timestamp_ns:$timestamp_ns,
       monitors:[{name:"HDMI-A-2",width:1920,height:1080,refreshRate:60,focused:true,activelyTearing:false}],
       gamescope_client:{address:"0xdef",pid:102},
       gamescope_property:{address:"0xdef",pid:102,immediate:true},
       hypr_options:{vfr:true,allow_tearing:true},activewindow:{address:"0xdef",class:"gamescope"}}
    '
    jq -cn --argjson timestamp_ns "$((timestamp + 3))" '
      {timestamp_ns:$timestamp_ns,
       monitors:[{name:"DP-1",width:1920,height:1080,refreshRate:60,focused:true,activelyTearing:false}],
       gamescope_client:{address:"0xabc",pid:999},
       gamescope_property:{address:"0xabc",pid:999,immediate:true},
       hypr_options:{vfr:true,allow_tearing:false},activewindow:{address:"0xabc",class:"gamescope"}}
    '
  } >> "$run_dir/hypr-state.ndjson"
}

write_runtime_receipts() {
  local run_dir=$1 game_overlay=$2 sample timestamp gamescope_pid=0 xwayland_pid=0 address=""
  timestamp=$(date +%s%N)
  sample=$(tail -n 1 "$run_dir/samples.tsv")
  [[ $sample != timestamp_ns$'\t'* ]] || fail "runtime fixture has no trace sample"
  if [[ ${GAMESCOPE_MODE:-enabled} == enabled ]]; then
    gamescope_pid=102
    xwayland_pid=103
    address=0xabc
  fi
  awk -F '\t' -v OFS='\t' \
    -v timestamp="$timestamp" -v gamescope_pid="$gamescope_pid" -v xwayland_pid="$xwayland_pid" '
      {$1=timestamp; $13=101; $22=gamescope_pid; $31=xwayland_pid; $40=104; print}
    ' <<< "$sample" >> "$run_dir/samples.tsv"
  printf '%s\n' \
    "$timestamp"$'\t101\thyprland\t/mock/Hyprland\t/mock/Hyprland' \
    "$timestamp"$'\t104\tskyrim\t/mock/SkyrimSE.exe\t/mock/SkyrimSE.exe' \
    >> "$run_dir/processes.tsv"
  if [[ ${GAMESCOPE_MODE:-enabled} == enabled ]]; then
    printf '%s\n' \
      "$timestamp"$'\t102\tgamescope\t'"$GAMESCOPE_BIN"$'\t'"$GAMESCOPE_BIN $GAMESCOPE_ARGS -- fixture" \
      "$timestamp"$'\t103\txwayland\t/mock/Xwayland\t/mock/Xwayland :1' \
      >> "$run_dir/processes.tsv"
    printf '%s\n' \
      $'address\t0xabc' \
      $'pid\t102' \
      $'expected_immediate\t'"$HYPR_IMMEDIATE" \
      $'actual_immediate\t'"$HYPR_IMMEDIATE" \
      $'expected_binary\t'"$GAMESCOPE_BIN" \
      $'actual_binary\t'"$GAMESCOPE_BIN" \
      $'expected_backend\t'"$GAMESCOPE_BACKEND" \
      $'cmdline\t'"$GAMESCOPE_BIN $GAMESCOPE_ARGS -- fixture" \
      > "$run_dir/client-verification.tsv"
  fi
  jq -cn \
    --argjson timestamp_ns "$timestamp" \
    --arg connector "$CONNECTOR" \
    --argjson width "$OUTPUT_WIDTH" \
    --argjson height "$OUTPUT_HEIGHT" \
    --argjson refresh "$REFRESH_HZ" \
    --argjson vfr "$HYPR_VFR" \
    --argjson tearing "$HYPR_ALLOW_TEARING" \
    --argjson immediate "$HYPR_IMMEDIATE" \
    --argjson gamescope_pid "$gamescope_pid" \
    --arg address "$address" '
      {timestamp_ns:$timestamp_ns,
       monitors:[{name:$connector,width:$width,height:$height,refreshRate:$refresh,
         focused:true,activelyTearing:false}],
       gamescope_client:(if $gamescope_pid > 0 then {address:$address,pid:$gamescope_pid} else null end),
       gamescope_property:{address:$address,pid:$gamescope_pid,immediate:$immediate},
       hypr_options:{vfr:$vfr,allow_tearing:$tearing},
       activewindow:{address:$address,class:"gamescope",title:"Skyrim Special Edition"}}
    ' >> "$run_dir/hypr-state.ndjson"
  printf '%s\n' \
    $'policy\t'"$OVERLAY_POLICY" \
    $'expected_game_overlay\t'"$game_overlay" \
    $'actual_game_overlay\t'"$game_overlay" \
    $'expected_gamescope_overlay\tfalse' \
    $'actual_gamescope_overlay\tfalse' \
    > "$run_dir/overlay-verification.tsv"
}

export HOME=$TEST_HOME
export XDG_STATE_HOME=$TEST_STATE
export SKYRIM_PERF_STATE_DIR=$TEST_STATE/skyrim-performance
export SKYRIM_BENCHMARK_MATRIX=$TEST_ROOT/matrix.tsv
export SKYRIM_BENCHMARK_PROFILES=$TEST_ROOT/profiles.tsv
export SKYRIM_BENCHMARK_PRESENTATION_MATRIX=$TEST_ROOT/presentation-matrix.tsv
export SKYRIM_BENCHMARK_PRESENTATION_PROFILES=$TEST_ROOT/presentation-profiles.tsv
export SKYRIM_BENCHMARK_MONITORS_JSON=$TEST_ROOT/monitors.json
export SKYRIM_BENCHMARK_BOOT_ID_FILE=$TEST_CONTROL/boot-id
export SKYRIM_BENCHMARK_MANGOHUD_CONFIG=$TEST_HOME/.config/MangoHud/skyrim-benchmark.conf
export SKYRIM_BENCHMARK_PREFS_INI=$TEST_ROOT/SkyrimPrefs.ini
export SKYRIM_BENCHMARK_SCOPE_LOG=$TEST_ROOT/scopebuddy.log
export SKYRIM_BENCHMARK_STEAM_BUILD=24604991
export SKYRIM_BENCHMARK_SKIP_PROCESS_CHECK=1
export SKYRIM_TEST_CONTROL_DIR=$TEST_CONTROL
export SKYRIM_TEST_GAMESCOPE_BIN=$TEST_GAMESCOPE_BIN

mkdir -p \
  "$TEST_HOME/.local/bin" \
  "$TEST_HOME/.config/MangoHud" \
  "$TEST_STATE" \
  "$TEST_CONTROL" \
  "$TEST_BIN" \
  "$TEST_GAMESCOPE_ROOT/bin" \
  "$TEST_GAMESCOPE_ROOT/share/gamescope/scripts"

cp "$MODULE_DIR/benchmark/matrix.tsv" "$SKYRIM_BENCHMARK_MATRIX"
cp "$MODULE_DIR/benchmark/profiles.tsv" "$SKYRIM_BENCHMARK_PROFILES"
cp "$MODULE_DIR/benchmark/presentation-matrix.tsv" "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"
cp "$MODULE_DIR/benchmark/presentation-profiles.tsv" "$SKYRIM_BENCHMARK_PRESENTATION_PROFILES"
cp "$MODULE_DIR/mangohud-benchmark.conf" "$SKYRIM_BENCHMARK_MANGOHUD_CONFIG"
ln -s "$CONTROLLER" "$TEST_HOME/.local/bin/skyrim-benchmark"

printf '%s\n' \
  $'bad-two-factors\tultrawide-native\tsystem\tsdl\tgame\ttrue\tfalse\ttrue\t0' \
  >> "$SKYRIM_BENCHMARK_PRESENTATION_PROFILES"
printf '%s\n' \
  $'BAD-TWO\tplanned\tH0\tbad-two-factors\thypr_allow_tearing\ttrue\tfalse\tindoor-v1\t0\t120\tfalse\tshort-1\trequired\tpending\tpending\tNA\tNA\tNA\tNA\tpending\tSynthetic invalid two-factor cell.' \
  $'BAD-REPEAT\tplanned\tH0\tultrawide-tearing-off\treplicate\tultrawide-h0\tultrawide-h0\tindoor-v1\t0\t120\tfalse\tshort-2\trequired\tpending\tpending\tNA\tNA\tNA\tNA\tpending\tSynthetic invalid repeat.' \
  $'CANCEL-TEST\tplanned\tH1-S\tultrawide-tearing-off\treplicate\tultrawide-tearing-off\tultrawide-tearing-off\tindoor-v1\t0\t120\tfalse\tshort-1\trequired\tpending\tpending\tNA\tNA\tNA\tNA\tpending\tSynthetic active-cancel restoration path.' \
  $'STATE-DRIFT\tplanned\tH1-S\tultrawide-tearing-off\treplicate\tultrawide-tearing-off\tultrawide-tearing-off\tindoor-v1\t0\t120\tfalse\tshort-1\trequired\tpending\tpending\tNA\tNA\tNA\tNA\tpending\tSynthetic client Hypr and topology drift path.' \
  $'INI-DRIFT\tplanned\tH1-S\tultrawide-tearing-off\treplicate\tultrawide-tearing-off\tultrawide-tearing-off\tindoor-v1\t0\t120\tfalse\tshort-1\trequired\tpending\tpending\tNA\tNA\tNA\tNA\tpending\tSynthetic generated INI drift path.' \
  >> "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

printf '%s\n' \
  $'TEST-FSR\tplanned\tT2\tfsr-900\treplicate\tfsr-900\tfsr-900\tindoor-v1\t60\t120\trequired\tpending\tNA\tNA\tNA\tpending\tSynthetic FSR run.' \
  >> "$SKYRIM_BENCHMARK_MATRIX"

awk -F '\t' '
  $1 ~ /^(ultrawide-tearing-off|ultrawide-gamescope-3[.]16[.]25|ultrawide-sdl|ultrawide-overlay-off|ultrawide-cap-45|ultrawide-gamescope-bypass|ultrawide-combine-pending)$/ {
    seen++; if ($7 != "false") bad=1
  }
  END {exit !(seen == 7 && !bad)}
' "$SKYRIM_BENCHMARK_PRESENTATION_PROFILES"
awk -F '\t' '
  $1 ~ /^(H2|H3|H4|H5|F1|C1)-1$/ {seen++; if ($3 != "H1-S") bad=1}
  END {exit !(seen == 6 && !bad)}
' "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

cat > "$TEST_GAMESCOPE_BIN" <<'EOF'
#!/usr/bin/env bash
set +x
if [[ ${1:-} == --version ]]; then
  printf 'gamescope version 3.16.23\n'
fi
EOF
cat > "$TEST_GAMESCOPE_ROOT/bin/gamescopereaper" <<'EOF'
#!/usr/bin/env bash
set +x
exit 0
EOF
cat > "$TEST_BIN/mangoapp" <<'EOF'
#!/usr/bin/env bash
set +x
exit 0
EOF
cat > "$TEST_BIN/journalctl" <<'EOF'
#!/usr/bin/env bash
set +x
if [[ " $* " == *' --show-cursor '* ]]; then
  printf '%s\n' '-- cursor: s=mock;i=1;b=boot'
fi
EOF
cat > "$TEST_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
set +x
# The benchmark worker must never discover or sample live game processes while
# this fixture suite runs. Runtime identities are supplied below as test data.
exit 1
EOF
cat > "$TEST_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
set +x
set -euo pipefail

control=${SKYRIM_TEST_CONTROL_DIR:?}
printf '%q ' "$@" >> "$control/hyprctl.log"
printf '\n' >> "$control/hyprctl.log"

bool_json() {
  if [[ $(<"$1") == true ]]; then
    printf '{"int":1,"set":true}\n'
  else
    printf '{"int":0,"set":true}\n'
  fi
}

set_bool() {
  case $2 in
    1|true|on|yes) printf 'true\n' > "$1" ;;
    0|false|off|no) printf 'false\n' > "$1" ;;
    *) exit 2 ;;
  esac
}

case " $* " in
  *' -j getoption debug:vfr '*)
    bool_json "$control/hypr-vfr"
    ;;
  *' -j getoption general:allow_tearing '*)
    bool_json "$control/hypr-tearing"
    ;;
  *' -j version '*)
    printf '{"tag":"v0.55.2","commit":"mock"}\n'
    ;;
  *' configerrors '*)
    ;;
  *' -j monitors all '*|*' -j monitors '*)
    tearing=false
    [[ $(<"$control/hypr-tearing") == true ]] && tearing=true
    printf '[{"id":0,"name":"DP-1","width":3440,"height":1440,"refreshRate":143.975,"focused":true,"activelyTearing":%s,"hardwareCursorsInUse":true,"directScanoutTo":"","directScanoutBlockedBy":""}]\n' "$tearing"
    ;;
  *' -j clients '*)
    printf '[{"address":"0xabc","class":"gamescope","title":"Skyrim Special Edition","xwayland":false,"fullscreen":2}]\n'
    ;;
  *' -j activewindow '*)
    printf '{"address":"0xabc","class":"gamescope","title":"Skyrim Special Edition"}\n'
    ;;
  *' getprop '*' immediate '*)
    if [[ $(<"$control/hypr-immediate") == true ]]; then
      printf 'int: 1\nset: true\n'
    else
      printf 'int: 0\nset: true\n'
    fi
    ;;
  *' keyword debug:vfr '*)
    if [[ -f $control/fail-vfr-apply ]]; then
      rm -f -- "$control/fail-vfr-apply"
      printf 'false\n' > "$control/hypr-vfr"
      printf 'ok\n'
      exit 0
    fi
    set_bool "$control/hypr-vfr" "${3:?}"
    printf 'ok\n'
    ;;
  *' keyword general:allow_tearing '*)
    set_bool "$control/hypr-tearing" "${3:?}"
    printf 'ok\n'
    ;;
  *' setprop '*' immediate '*)
    set_bool "$control/hypr-immediate" "${4:?}"
    printf 'ok\n'
    ;;
  *)
    printf '{}\n'
    ;;
esac
EOF
cat > "$TEST_HOME/.local/bin/skyrim-configure-display" <<'EOF'
#!/usr/bin/env bash
set +x
set -euo pipefail
printf 'iSize W=%s\niSize H=%s\nbBorderless=1\n' "$1" "$2" > "$SKYRIM_BENCHMARK_PREFS_INI"
EOF
chmod +x \
  "$TEST_GAMESCOPE_BIN" \
  "$TEST_GAMESCOPE_ROOT/bin/gamescopereaper" \
  "$TEST_BIN/mangoapp" \
  "$TEST_BIN/journalctl" \
  "$TEST_BIN/pgrep" \
  "$TEST_BIN/hyprctl" \
  "$TEST_HOME/.local/bin/skyrim-configure-display"
export PATH="$TEST_GAMESCOPE_ROOT/bin:$TEST_BIN:$TEST_HOME/.local/bin:$PATH"

printf '%s\n' true > "$TEST_CONTROL/hypr-vfr"
printf '%s\n' false > "$TEST_CONTROL/hypr-tearing"
printf '%s\n' true > "$TEST_CONTROL/hypr-immediate"
printf '%s\n' boot-a > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
printf '%s\n' \
  '[{"name":"DP-1","width":3440,"height":1440,"refreshRate":143.975,"focused":true}]' \
  > "$SKYRIM_BENCHMARK_MONITORS_JSON"

native_profile=$($CONTROLLER profile ultrawide-native)
grep -Fxq 'GAME=3440x1440' <<< "$native_profile"
grep -Fxq 'OUTPUT=3440x1440@144 DP-1' <<< "$native_profile"
grep -Fxq 'NESTED=output-default' <<< "$native_profile"

expect_failure_matching \
  'two-factor presentation row' \
  'exactly one|changes' \
  "$CONTROLLER" queue BAD-TWO
expect_failure_matching \
  'repeat that changes a profile field' \
  'replicate.*changes|changes.*replicate' \
  "$CONTROLLER" queue BAD-REPEAT

$CONTROLLER queue H1-1 > "$TEST_ROOT/h1-waiting.receipt"
grep -Fxq 'STATE=WAITING_FOR_REBOOT' "$TEST_ROOT/h1-waiting.receipt"
grep -Fxq 'RUN_KIND=presentation' "$TEST_ROOT/h1-waiting.receipt"
grep -Fxq 'OUTPUT=3440x1440@144 DP-1' "$TEST_ROOT/h1-waiting.receipt"
grep -Fxq 'HUD=enabled' "$TEST_ROOT/h1-waiting.receipt"
grep -Fxq 'SYSTEM_TRACE=automatic' "$TEST_ROOT/h1-waiting.receipt"
grep -Fxq 'MANGOHUD_RECORDING=manual Left Shift+F2' "$TEST_ROOT/h1-waiting.receipt"

H1_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/H1-1
# shellcheck disable=SC1090,SC1091
source "$H1_RUN_DIR/prepared.env"
[[ $GAMESCOPE_SOURCE == system ]]
[[ $GAMESCOPE_BIN == "$TEST_GAMESCOPE_BIN" ]]
[[ $GAMESCOPE_BIN_DIR == "$TEST_GAMESCOPE_ROOT/bin" ]]
[[ $GAMESCOPE_SCRIPT_PATH == "$TEST_GAMESCOPE_ROOT/share/gamescope/scripts" ]]
[[ $GAMESCOPE_BACKEND == wayland ]]
[[ $OVERLAY_POLICY == game ]]
[[ $HYPR_VFR == true && $HYPR_ALLOW_TEARING == false && $HYPR_IMMEDIATE == true ]]
[[ $GAMESCOPE_ARGS == '-f --grab --backend wayland --prefer-output DP-1 --force-windows-fullscreen --mangoapp -W 3440 -H 1440' ]]

expect_failure_matching \
  'launch before required reboot' \
  'reboot|WAITING' \
  "$CONTROLLER" activate H1-1 "$GAMESCOPE_ARGS"

printf '%s\n' boot-b > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h1-first

printf '%s\n' false > "$TEST_CONTROL/hypr-vfr"
expect_failure_matching \
  'VFR drift' \
  'vfr.*drift|drift.*vfr' \
  "$CONTROLLER" status
printf '%s\n' true > "$TEST_CONTROL/hypr-vfr"

printf '%s\n' true > "$TEST_CONTROL/hypr-tearing"
expect_failure_matching \
  'tearing drift' \
  'allow_tearing.*drift|tearing.*drift|drift.*tearing' \
  "$CONTROLLER" status
printf '%s\n' false > "$TEST_CONTROL/hypr-tearing"

SCB_GAMESCOPE_ARGS='ambient arguments that must be replaced'
SCB_AUTO_RES=1
SCB_AUTO_HDR=1
SCB_AUTO_VRR=1
SCB_AUTO_REFRESH=1
SCB_AUTO_FRAME_LIMIT=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"

[[ $SCB_GAMESCOPE_ARGS == "$GAMESCOPE_ARGS" ]]
[[ $SCB_AUTO_RES == 0 && $SCB_AUTO_HDR == 0 && $SCB_AUTO_VRR == 0 ]]
[[ $SCB_AUTO_REFRESH == 0 && $SCB_AUTO_FRAME_LIMIT == 0 && $SCB_APPENDMODE == 0 ]]
[[ $PATH == "$GAMESCOPE_BIN_DIR":* ]]
[[ $GAMESCOPE_SCRIPT_PATH == "$TEST_GAMESCOPE_ROOT/share/gamescope/scripts" ]]
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
wait_for_lines "$H1_RUN_DIR/samples.tsv" 2
wait_for_file "$H1_RUN_DIR/hypr-state.ndjson"
[[ $(<"$H1_RUN_DIR/trace-status") == running ]]
write_runtime_receipts "$H1_RUN_DIR" true

$CONTROLLER post-launch H1-1
[[ $(<"$H1_RUN_DIR/trace-status") == stopped ]]
[[ $(<"$TEST_CONTROL/hypr-vfr") == true ]]
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
jq -e '.passed == true' "$H1_RUN_DIR/runtime-verification.json" >/dev/null
write_dense_trace_span "$H1_RUN_DIR" 199

expect_failure_matching \
  'accepted short run without MangoHud data' \
  'MangoHud|summary|recording' \
  "$CONTROLLER" complete H1-1 \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Missing MangoHud must fail.'

write_mangohud_recording "$H1_RUN_DIR" 109000000000
expect_failure_matching \
  'short MangoHud recording below tolerance' \
  'recording lasted.*expected.*120' \
  "$CONTROLLER" complete H1-1 \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Short recording must fail.'

write_mangohud_recording "$H1_RUN_DIR" 131000000000
expect_failure_matching \
  'short MangoHud recording above tolerance' \
  'recording lasted.*expected.*120' \
  "$CONTROLLER" complete H1-1 \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Long recording must fail.'

write_mangohud_recording "$H1_RUN_DIR"
expect_failure_matching \
  'accepted short run without desktop observation' \
  'good game and desktop cursor' \
  "$CONTROLLER" complete H1-1 \
    --game-cursor good \
    --desktop-cursor not-tested \
    --verdict accepted \
    --notes 'Desktop observation must be required.'
expect_failure_matching \
  'accepted short run without full automatic trace' \
  'automatic trace lasted.*expected at least 200' \
  "$CONTROLLER" complete H1-1 \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Short trace must fail.'
write_gappy_trace_span "$H1_RUN_DIR" 210
expect_failure_matching \
  'accepted short run with a gappy automatic trace' \
  'trace.*(coverage|gap|continu)|sample.*coverage' \
  "$CONTROLLER" complete H1-1 \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Gappy short trace must fail.'
write_dense_trace_span "$H1_RUN_DIR" 210
$CONTROLLER complete H1-1 \
  --game-cursor good \
  --desktop-cursor good \
  --verdict accepted \
  --notes 'Synthetic accepted short presentation run.' \
  > "$TEST_ROOT/h1-completed.receipt"
grep -Fxq 'STATE=completed' "$TEST_ROOT/h1-completed.receipt"
awk -F '\t' '$1 == "H1-1" { exit !($2 == "completed" && $14 == "good" && $15 == "good" && $16 == "0" && $20 == "accepted") }' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"
awk -F '\t' '$1 == "H1-2" { exit !($2 == "planned") }' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

# An exact repeat is eligible only after the first short run is accepted.
printf '%s\n' boot-b > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
$CONTROLLER queue H1-2 > "$TEST_ROOT/h1-repeat-waiting.receipt"
grep -Fxq 'STATE=WAITING_FOR_REBOOT' "$TEST_ROOT/h1-repeat-waiting.receipt"
printf '%s\n' boot-c > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h1-repeat

SCB_GAMESCOPE_ARGS='ambient repeat arguments'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
H1_REPEAT_DIR=$SKYRIM_PERF_STATE_DIR/runs/H1-2
wait_for_lines "$H1_REPEAT_DIR/samples.tsv" 2
$CONTROLLER mark stall-recovered --scope desktop
grep -q $'stall-recovered\tdesktop' "$H1_REPEAT_DIR/events.tsv"
write_runtime_receipts "$H1_REPEAT_DIR" true
$CONTROLLER post-launch H1-2
[[ $(<"$H1_REPEAT_DIR/trace-status") == stopped ]]
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
jq -e '.passed == true' "$H1_REPEAT_DIR/runtime-verification.json" >/dev/null
[[ ! -e $H1_REPEAT_DIR/mangohud.csv && ! -e $H1_REPEAT_DIR/mangohud_summary.csv ]]

$CONTROLLER complete H1-2 \
  --game-cursor bad \
  --desktop-cursor bad \
  --verdict rejected \
  --notes 'Synthetic cursor/compositor failure without MangoHud.' \
  > "$TEST_ROOT/h1-repeat-completed.receipt"
grep -Fxq 'STATE=completed' "$TEST_ROOT/h1-repeat-completed.receipt"
awk -F '\t' '$1 == "H1-2" { exit !($2 == "completed" && $13 ~ /^automatic-trace/ && $14 == "bad" && $15 == "bad" && $16 == "1" && $20 == "rejected") }' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"
awk -F '\t' 'NR > 1 {count[$7]++} END {exit !(count["ambiguous"] == 1)}' \
  "$H1_REPEAT_DIR/event-classifications.tsv"
jq -e '.stall_classification == {frame_freeze:0,cursor_compositor_stall:0,ambiguous:1}' \
  "$H1_REPEAT_DIR/observation.json" >/dev/null

# Preserve the cursor-failure branch, then prove a repeat that improves by more
# than 5% is inconclusive instead of silently accepted as the same condition.
mv -- "$H1_REPEAT_DIR" "$TEST_ROOT/h1-repeat-rejected"
reset_presentation_run H1-2
$CONTROLLER queue H1-2 > "$TEST_ROOT/h1-repeat-improved-waiting.receipt"
grep -Fxq 'STATE=WAITING_FOR_REBOOT' "$TEST_ROOT/h1-repeat-improved-waiting.receipt"
printf '%s\n' boot-d > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h1-repeat-improved
SCB_GAMESCOPE_ARGS='ambient improved-repeat arguments'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
H1_REPEAT_DIR=$SKYRIM_PERF_STATE_DIR/runs/H1-2
wait_for_lines "$H1_REPEAT_DIR/samples.tsv" 2
write_runtime_receipts "$H1_REPEAT_DIR" true
$CONTROLLER post-launch H1-2
jq -e '.passed == true' "$H1_REPEAT_DIR/runtime-verification.json" >/dev/null
write_dense_trace_span "$H1_REPEAT_DIR" 210
write_mangohud_recording "$H1_REPEAT_DIR" 120000000000 70.0 50.0 35.0
expect_failure_matching \
  'repeat with a greater-than-5-percent improvement' \
  '5%|5 percent|rerun|inconclusive|difference' \
  "$CONTROLLER" complete H1-2 \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Large repeat improvement must require another run.'
$CONTROLLER complete H1-2 \
  --game-cursor good \
  --desktop-cursor good \
  --verdict inconclusive \
  --notes 'Synthetic improved repeat requires rerun.' \
  >/dev/null
awk -F '\t' '$1 == "H1-2" {exit !($2 == "completed" && $20 == "inconclusive")}' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

# Rerun the exact repeat with metrics inside the symmetric tolerance so the
# real chain can promote its soak and later candidates.
mv -- "$H1_REPEAT_DIR" "$TEST_ROOT/h1-repeat-improved"
reset_presentation_run H1-2
$CONTROLLER queue H1-2 > "$TEST_ROOT/h1-repeat-accepted-waiting.receipt"
grep -Fxq 'STATE=WAITING_FOR_REBOOT' "$TEST_ROOT/h1-repeat-accepted-waiting.receipt"
printf '%s\n' boot-e > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h1-repeat-accepted
SCB_GAMESCOPE_ARGS='ambient accepted-repeat arguments'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
H1_REPEAT_DIR=$SKYRIM_PERF_STATE_DIR/runs/H1-2
wait_for_lines "$H1_REPEAT_DIR/samples.tsv" 2
write_runtime_receipts "$H1_REPEAT_DIR" true
$CONTROLLER post-launch H1-2
jq -e '.passed == true' "$H1_REPEAT_DIR/runtime-verification.json" >/dev/null
write_dense_trace_span "$H1_REPEAT_DIR" 210
write_mangohud_recording "$H1_REPEAT_DIR"
$CONTROLLER complete H1-2 \
  --game-cursor good \
  --desktop-cursor good \
  --verdict accepted \
  --notes 'Synthetic accepted exact repeat.' \
  >/dev/null
awk -F '\t' '$1 == "H1-S" {exit !($2 == "planned")}' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

# The promoted real soak is accepted from automatic system evidence alone. It
# rejects one second below duration and does not require 4.5h of Mango data.
$CONTROLLER queue H1-S > "$TEST_ROOT/h1-soak-waiting.receipt"
grep -Fxq 'STATE=WAITING_FOR_REBOOT' "$TEST_ROOT/h1-soak-waiting.receipt"
printf '%s\n' boot-f > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h1-soak
SCB_GAMESCOPE_ARGS='ambient soak arguments'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
SOAK_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/H1-S
wait_for_lines "$SOAK_RUN_DIR/samples.tsv" 2
write_runtime_receipts "$SOAK_RUN_DIR" true
$CONTROLLER post-launch H1-S
jq -e '.passed == true' "$SOAK_RUN_DIR/runtime-verification.json" >/dev/null
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
write_dense_trace_span "$SOAK_RUN_DIR" 16199
expect_failure_matching \
  'soak shorter than its automatic-trace duration' \
  'soak trace lasted.*expected at least 16200' \
  "$CONTROLLER" complete H1-S \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Short soak trace must fail.'
write_gappy_trace_span "$SOAK_RUN_DIR" 16200
expect_failure_matching \
  'soak with a gappy automatic trace' \
  'trace.*(coverage|gap|continu)|sample.*coverage' \
  "$CONTROLLER" complete H1-S \
    --game-cursor good \
    --desktop-cursor good \
    --verdict accepted \
    --notes 'Gappy soak trace must fail.'
write_dense_trace_span "$SOAK_RUN_DIR" 16200
[[ ! -e $SOAK_RUN_DIR/mangohud.csv && ! -e $SOAK_RUN_DIR/mangohud_summary.csv ]]
$CONTROLLER complete H1-S \
  --game-cursor good \
  --desktop-cursor good \
  --verdict accepted \
  --notes 'Synthetic automatic-trace-only soak.' \
  >/dev/null
awk -F '\t' '$1 == "H1-S" {exit !($2 == "completed" && $13 ~ /mangohud-not-recorded/ && $20 == "accepted")}' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

# Once a client and display topology have been verified, every later
# applicable Hypr sample must remain tied to that PID/address/immediate state,
# the prepared compositor options, and the exact display topology.
$CONTROLLER queue STATE-DRIFT > "$TEST_ROOT/state-drift-ready.receipt"
grep -Fxq 'STATE=READY' "$TEST_ROOT/state-drift-ready.receipt"
SCB_GAMESCOPE_ARGS='ambient state-drift arguments'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
STATE_DRIFT_DIR=$SKYRIM_PERF_STATE_DIR/runs/STATE-DRIFT
wait_for_lines "$STATE_DRIFT_DIR/samples.tsv" 2
write_runtime_receipts "$STATE_DRIFT_DIR" true
append_runtime_drift_states "$STATE_DRIFT_DIR"
$CONTROLLER post-launch STATE-DRIFT
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
jq -e '.passed == false and
  (.errors | test("client|address|pid"; "i")) and
  (.errors | test("immediate"; "i")) and
  (.errors | test("vfr|tearing|Hyprland option"; "i")) and
  (.errors | test("topology|monitor|display"; "i"))' \
  "$STATE_DRIFT_DIR/runtime-verification.json" >/dev/null
write_dense_trace_span "$STATE_DRIFT_DIR" 210
write_mangohud_recording "$STATE_DRIFT_DIR"
expect_all_completion_verdicts_refused \
  STATE-DRIFT \
  'runtime verification|client|immediate|Hyprland option|topology|monitor|display'
$CONTROLLER invalidate STATE-DRIFT 'synthetic client Hypr and topology drift' >/dev/null
awk -F '\t' '$1 == "STATE-DRIFT" {exit !($2 == "invalid")}' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

# Width and height remaining correct cannot hide drift elsewhere in the full
# generated SkyrimPrefs.ini used for the run.
$CONTROLLER queue INI-DRIFT > "$TEST_ROOT/ini-drift-ready.receipt"
grep -Fxq 'STATE=READY' "$TEST_ROOT/ini-drift-ready.receipt"
SCB_GAMESCOPE_ARGS='ambient INI-drift arguments'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
INI_DRIFT_DIR=$SKYRIM_PERF_STATE_DIR/runs/INI-DRIFT
wait_for_lines "$INI_DRIFT_DIR/samples.tsv" 2
write_runtime_receipts "$INI_DRIFT_DIR" true
printf 'iSize W=3440\niSize H=1440\nbBorderless=0\n' > "$SKYRIM_BENCHMARK_PREFS_INI"
$CONTROLLER post-launch INI-DRIFT
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
jq -e '.passed == false and (.errors | test("INI|prefs|configuration|config"; "i"))' \
  "$INI_DRIFT_DIR/runtime-verification.json" >/dev/null
write_dense_trace_span "$INI_DRIFT_DIR" 210
write_mangohud_recording "$INI_DRIFT_DIR"
expect_all_completion_verdicts_refused \
  INI-DRIFT \
  'runtime verification|INI|prefs|configuration|config'
$CONTROLLER invalidate INI-DRIFT 'synthetic generated INI drift' >/dev/null
awk -F '\t' '$1 == "INI-DRIFT" {exit !($2 == "invalid")}' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"
"$TEST_HOME/.local/bin/skyrim-configure-display" 3440 1440

# Queue an SDL cell to prove backend selection changes the generated command
# and nothing else in the launch contract.
set_presentation_status H3-1 planned
$CONTROLLER queue H3-1 > "$TEST_ROOT/h3-waiting.receipt"
printf '%s\n' boot-g > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h3
# shellcheck disable=SC1090,SC1091
source "$SKYRIM_PERF_STATE_DIR/runs/H3-1/prepared.env"
[[ $GAMESCOPE_BIN == "$TEST_GAMESCOPE_BIN" ]]
[[ $GAMESCOPE_BACKEND == sdl ]]
[[ $OVERLAY_POLICY == game ]]
[[ $HYPR_ALLOW_TEARING == false ]]
[[ $GAMESCOPE_ARGS == '-f --grab --backend sdl --prefer-output DP-1 --force-windows-fullscreen --mangoapp -W 3440 -H 1440' ]]
$CONTROLLER activate H3-1 "$GAMESCOPE_ARGS"
H3_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/H3-1
wait_for_lines "$H3_RUN_DIR/samples.tsv" 2
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
write_runtime_receipts "$H3_RUN_DIR" true
touch "$H3_RUN_DIR/trace-stop"
wait_for_value "$H3_RUN_DIR/trace-status" stopped
printf 'forced-stopped\n' > "$H3_RUN_DIR/trace-status"
$CONTROLLER post-launch H3-1
[[ $(<"$H3_RUN_DIR/trace-status") == forced-stopped ]]
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
[[ -s $H3_RUN_DIR/runtime-hypr-restored ]]
jq -e '.passed == false and (.errors | contains("automatic trace did not stop cleanly"))' \
  "$H3_RUN_DIR/runtime-verification.json" >/dev/null
write_dense_trace_span "$H3_RUN_DIR" 210
write_mangohud_recording "$H3_RUN_DIR"
expect_all_completion_verdicts_refused \
  H3-1 \
  'automatic trace did not stop cleanly|failed runtime verification'
$CONTROLLER invalidate H3-1 'synthetic forced trace-stop rejection' >/dev/null
awk -F '\t' '$1 == "H3-1" {exit !($2 == "invalid")}' \
  "$SKYRIM_BENCHMARK_PRESENTATION_MATRIX"

# Active cancellation uses the same automatic trace and runtime restore path
# but must leave no armed/active run or worker behind.
$CONTROLLER queue CANCEL-TEST > "$TEST_ROOT/cancel-ready.receipt"
grep -Fxq 'STATE=READY' "$TEST_ROOT/cancel-ready.receipt"
# shellcheck disable=SC1090,SC1091
source "$SKYRIM_PERF_STATE_DIR/runs/CANCEL-TEST/prepared.env"
[[ $HYPR_ALLOW_TEARING == false ]]
$CONTROLLER activate CANCEL-TEST "$GAMESCOPE_ARGS"
CANCEL_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/CANCEL-TEST
wait_for_lines "$CANCEL_RUN_DIR/samples.tsv" 2
$CONTROLLER cancel >/dev/null
[[ $(<"$CANCEL_RUN_DIR/trace-status") == stopped ]]
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
[[ -s $CANCEL_RUN_DIR/runtime-hypr-restored ]]
[[ ! -e $SKYRIM_PERF_STATE_DIR/armed-run && ! -e $SKYRIM_PERF_STATE_DIR/active-run ]]

# A failure after the runtime profile begins applying must restore the ambient
# category-wide tearing policy before the controller returns an error.
set_presentation_status H5-1 planned
$CONTROLLER queue H5-1 > "$TEST_ROOT/h5-waiting.receipt"
printf '%s\n' boot-h > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h5
# shellcheck disable=SC1090,SC1091
source "$SKYRIM_PERF_STATE_DIR/runs/H5-1/prepared.env"
[[ $HYPR_ALLOW_TEARING == false ]]
touch "$TEST_CONTROL/fail-vfr-apply"
expect_failure_matching \
  'failed runtime Hypr profile application' \
  'could not apply debug:vfr=true' \
  "$CONTROLLER" activate H5-1 "$GAMESCOPE_ARGS"
H5_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/H5-1
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
[[ -s $H5_RUN_DIR/runtime-hypr-restored ]]
[[ ! -e $SKYRIM_PERF_STATE_DIR/active-run ]]
$CONTROLLER cancel >/dev/null

# Overlay-off is tested through ScopeBuddy itself. Valid libc aliases avoid
# loader warnings while giving the filter realistic Steam-library basenames.
set_presentation_status H4-1 planned
$CONTROLLER queue H4-1 > "$TEST_ROOT/h4-waiting.receipt"
printf '%s\n' boot-i > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready h4
ln -s /usr/lib/libc.so.6 "$TEST_ROOT/gameoverlayrenderer.so"
ln -s /usr/lib/libc.so.6 "$TEST_ROOT/keep-preload.so"
export LD_PRELOAD="$TEST_ROOT/gameoverlayrenderer.so:$TEST_ROOT/keep-preload.so"
SCB_GAMESCOPE_ARGS='ambient overlay arguments'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
[[ $OVERLAY_POLICY == off ]]
[[ $HYPR_ALLOW_TEARING == false ]]
[[ $LD_PRELOAD == "$TEST_ROOT/keep-preload.so" ]]
[[ $SCB_GAMESCOPE_ARGS == "$GAMESCOPE_ARGS" ]]
H4_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/H4-1
wait_for_lines "$H4_RUN_DIR/samples.tsv" 2
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
$CONTROLLER mark stall-recovered --scope game >/dev/null
$CONTROLLER mark stall-recovered --scope game >/dev/null
$CONTROLLER mark stall-recovered --scope desktop >/dev/null
$CONTROLLER mark stall-recovered --scope desktop >/dev/null
[[ $(awk -F '\t' 'NR > 1 && $3 == "stall-recovered" {n++} END {print n+0}' "$H4_RUN_DIR/events.tsv") == 4 ]]
write_runtime_receipts "$H4_RUN_DIR" false
$CONTROLLER post-launch H4-1
[[ $(<"$H4_RUN_DIR/trace-status") == stopped ]]
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
jq -e '.passed == true' "$H4_RUN_DIR/runtime-verification.json" >/dev/null
write_classification_recording "$H4_RUN_DIR"
$CONTROLLER complete H4-1 \
  --game-cursor bad \
  --desktop-cursor good \
  --verdict rejected \
  --notes 'Synthetic overlay integration failure path.' \
  >/dev/null
awk -F '\t' 'NR > 1 {count[$7]++} END {
  exit !(count["cursor/compositor-stall"] == 1 && count["frame-freeze"] == 1 && count["ambiguous"] == 2)
}' "$H4_RUN_DIR/event-classifications.tsv"
jq -e '.stall_count == 4 and
  .stall_classification == {frame_freeze:1,cursor_compositor_stall:1,ambiguous:2}' \
  "$H4_RUN_DIR/observation.json" >/dev/null
unset LD_PRELOAD

# Bypass remains a falsification cell, but it must retain the same lifecycle
# and use MangoHud without accidentally invoking an ambient Gamescope command.
set_presentation_status F1-1 planned
$CONTROLLER queue F1-1 > "$TEST_ROOT/f1-waiting.receipt"
printf '%s\n' boot-j > "$SKYRIM_BENCHMARK_BOOT_ID_FILE"
assert_ready f1
# shellcheck disable=SC1090,SC1091
source "$SKYRIM_PERF_STATE_DIR/runs/F1-1/prepared.env"
[[ $GAMESCOPE_MODE == bypass ]]
[[ $HYPR_ALLOW_TEARING == false ]]
[[ -z $GAMESCOPE_BIN && -z $GAMESCOPE_BIN_DIR && -z $GAMESCOPE_SCRIPT_PATH && -z $GAMESCOPE_ARGS ]]
SCB_GAMESCOPE_ARGS='ambient arguments forbidden in bypass mode'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
[[ $SCB_NOSCOPE == 1 && $MANGOHUD == 1 ]]
F1_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/F1-1
wait_for_lines "$F1_RUN_DIR/samples.tsv" 2
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
write_runtime_receipts "$F1_RUN_DIR" true
$CONTROLLER post-launch F1-1
[[ $(<"$F1_RUN_DIR/trace-status") == stopped ]]
[[ $(<"$TEST_CONTROL/hypr-tearing") == false ]]
jq -e '.passed == true' "$F1_RUN_DIR/runtime-verification.json" >/dev/null
$CONTROLLER complete F1-1 \
  --game-cursor bad \
  --desktop-cursor good \
  --verdict rejected \
  --notes 'Synthetic gamescope bypass falsification.' \
  >/dev/null

# Legacy FPS rows retain their original profile construction and MangoHud-only
# completion semantics.
printf '%s\n' \
  '[{"name":"HDMI-A-2","width":1920,"height":1080,"refreshRate":60.0,"focused":true}]' \
  > "$SKYRIM_BENCHMARK_MONITORS_JSON"
$CONTROLLER queue TEST-FSR > "$TEST_ROOT/legacy.receipt"
grep -Fxq 'STATE=READY' "$TEST_ROOT/legacy.receipt"
grep -Fxq 'RUN_KIND=legacy' "$TEST_ROOT/legacy.receipt"
SCB_GAMESCOPE_ARGS='-f --grab --backend wayland --prefer-output HDMI-A-2'
SCB_AUTO_RES=1
# shellcheck disable=SC1091
source "$MODULE_DIR/scopebuddy.conf"
[[ $SCB_AUTO_RES == 0 ]]
[[ " $SCB_GAMESCOPE_ARGS " == *' --mangoapp '* ]]
[[ " $SCB_GAMESCOPE_ARGS " == *' -w 1600 -h 900 -S fit -F fsr '* ]]
[[ " $SCB_GAMESCOPE_ARGS " == *' -W 1920 -H 1080 '* ]]
[[ " $SCB_GAMESCOPE_ARGS " != *' --force-grab-cursor '* ]]
$CONTROLLER post-launch TEST-FSR
LEGACY_RUN_DIR=$SKYRIM_PERF_STATE_DIR/runs/TEST-FSR
write_mangohud_recording "$LEGACY_RUN_DIR"
$CONTROLLER complete TEST-FSR \
  --cursor bad \
  --verdict rejected \
  --notes 'Synthetic legacy cursor failure.' \
  >/dev/null

# With no armed run, ScopeBuddy must preserve normal play: native auto-size,
# no debug HUD, no automatic instrumentation, and no presentation override.
(
  unset MANGOHUD_CONFIG MANGOHUD_CONFIGFILE SCB_POST_COMMAND SKYRIM_BENCHMARK_RUN_ID
  SCB_GAMESCOPE_ARGS='-f --grab --backend wayland --prefer-output HDMI-A-2'
  SCB_AUTO_RES=1
  SCB_AUTO_HDR=1
  SCB_AUTO_VRR=1
  # shellcheck disable=SC1091
  source "$MODULE_DIR/scopebuddy.conf"
  [[ $SCB_AUTO_RES == 1 && $SCB_AUTO_HDR == 1 && $SCB_AUTO_VRR == 1 ]]
  [[ $SCB_GAMESCOPE_ARGS == '-f --grab --backend wayland --prefer-output HDMI-A-2 --force-windows-fullscreen' ]]
  [[ $SCB_PRE_COMMAND == *'skyrim-configure-display'* ]]
  [[ -z ${MANGOHUD_CONFIG+x} && -z ${MANGOHUD_CONFIGFILE+x} ]]
  [[ -z ${SCB_POST_COMMAND+x} ]]
)

[[ $($CONTROLLER status) == 'STATE=NO_ACTIVE_RUN' ]]
printf 'benchmark self-test: PASS\n'
