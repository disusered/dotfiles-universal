#!/usr/bin/env zsh
set -euo pipefail

repo_root=${0:A:h:h:h:h}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
export DEEPSEEK_TEST_ROOT="$test_root"
mkdir -p "$test_root/bin"
cat > "$test_root/bin/op" <<'SH'
#!/bin/sh
test "$1" = read && test "$2" = op://Personal/Deepseek/credential || exit 90
case "$DEEPSEEK_TEST_MODE" in
  fail) exit 17 ;;
  empty) exit 0 ;;
  *) printf '%s' 'mock-key' ;;
esac
SH
chmod +x "$test_root/bin/op"
export PATH="$test_root/bin:$PATH"
source "$repo_root/ai/codex/deepseek.zsh"

# A function stands in for the installed OpenViking-aware codex function.
codex() {
  [[ "$DEEPSEEK_API_KEY" == mock-key ]] || return 91
  print -rl -- "$@" > "$DEEPSEEK_TEST_ROOT/args"
  return 23
}
export DEEPSEEK_TEST_MODE=ok
result=0
codex-deepseek exec 'two words' --color never || result=$?
[[ $result == 23 ]]
expected=(--profile deepseek exec 'two words' --color never)
[[ "$(cat "$test_root/args")" == "$(print -rl -- "${expected[@]}")" ]]
[[ -z ${DEEPSEEK_API_KEY+x} ]]

result=0
(set -x; codex-deepseek exec 'trace check') > "$test_root/trace" 2>&1 || result=$?
[[ $result == 23 ]]
[[ "$(cat "$test_root/trace")" != *mock-key* ]]

for mode in fail empty; do
  export DEEPSEEK_TEST_MODE=$mode
  rm "$test_root/args"
  result=0
  codex-deepseek > "$test_root/output" 2>&1 || result=$?
  [[ $result != 0 && ! -e "$test_root/args" ]]
  [[ "$(cat "$test_root/output")" != *mock-key* ]]
  touch "$test_root/args"
done
print 'ok'
