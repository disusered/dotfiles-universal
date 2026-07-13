#!/usr/bin/env zsh
set -euo pipefail

if [[ "${CLIPROXYAPI_HELPERS_MOCK_MODE:-}" == 1 ]]; then
  print -r -- 'mock credential' > "$CLIPROXYAPI_MOCK_CREDENTIAL"
  for arg in "$@"; do
    print -r -- "$arg" >> "$CLIPROXYAPI_MOCK_LOG"
  done
  print -r -- '---' >> "$CLIPROXYAPI_MOCK_LOG"
  exit 0
fi

repo_root=${0:A:h:h:h:h}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

export HOME="$test_root/home"
export ZDOTDIR="$test_root/zdotdir"
mkdir -p "$HOME" "$ZDOTDIR"
source "$repo_root/ai/cliproxyapi/cliproxyapi.zsh"

assert_eq() {
  local expected=$1
  local actual=$2
  local label=$3

  if [[ "$actual" != "$expected" ]]; then
    print -ru2 -- "not ok: $label"
    print -ru2 -- "expected: $expected"
    print -ru2 -- "actual:   $actual"
    exit 1
  fi
}

assert_contains() {
  local actual=$1
  local expected_part=$2
  local label=$3

  if [[ "$actual" != *"$expected_part"* ]]; then
    print -ru2 -- "not ok: $label"
    print -ru2 -- "expected to contain: $expected_part"
    print -ru2 -- "actual:              $actual"
    exit 1
  fi
}

typeset -gi mock_claude_calls=0
typeset -g mock_anthropic_base_url
typeset -g mock_anthropic_auth_token
typeset -g mock_gateway_model_discovery
typeset -g mock_subagent_model
typeset -g mock_always_enable_effort
typeset -g mock_max_tool_use_concurrency
typeset -g mock_enable_tool_search
typeset -g mock_external_env
typeset -ga mock_claude_args

claude() {
  (( mock_claude_calls += 1 ))
  mock_anthropic_base_url=${ANTHROPIC_BASE_URL-}
  mock_anthropic_auth_token=${ANTHROPIC_AUTH_TOKEN-}
  mock_gateway_model_discovery=${CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY-}
  mock_subagent_model=${CLAUDE_CODE_SUBAGENT_MODEL-}
  mock_always_enable_effort=${CLAUDE_CODE_ALWAYS_ENABLE_EFFORT-}
  mock_max_tool_use_concurrency=${CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY-}
  mock_enable_tool_search=${ENABLE_TOOL_SEARCH-}
  mock_external_env=$(/usr/bin/env)
  mock_claude_args=("$@")
}

unset XDG_STATE_HOME
fallback_token_file="$HOME/.local/state/cliproxyapi/client-token"
mkdir -p "${fallback_token_file:h}"
print -r -- 'fallback-token' > "$fallback_token_file"

claudex --effort medium --print 'fallback prompt'

assert_eq '1' "$mock_claude_calls" 'fallback invocation reaches the shell claude function'
assert_eq 'http://127.0.0.1:8317' "$mock_anthropic_base_url" 'base URL'
assert_eq 'fallback-token' "$mock_anthropic_auth_token" 'fallback token'
assert_eq '1' "$mock_gateway_model_discovery" 'gateway model discovery'
assert_eq 'gpt-5.6-sol' "$mock_subagent_model" 'subagent model'
assert_eq '1' "$mock_always_enable_effort" 'effort flag'
assert_eq '3' "$mock_max_tool_use_concurrency" 'tool concurrency'
assert_eq 'false' "$mock_enable_tool_search" 'tool search flag'
assert_contains "$mock_external_env" 'ANTHROPIC_BASE_URL=http://127.0.0.1:8317' 'base URL is exported to Claude'
assert_contains "$mock_external_env" 'ANTHROPIC_AUTH_TOKEN=fallback-token' 'client token is exported to Claude'
assert_contains "$mock_external_env" 'CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1' 'gateway model discovery is exported to Claude'
assert_contains "$mock_external_env" 'CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol' 'subagent model is exported to Claude'
assert_contains "$mock_external_env" 'CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1' 'effort flag is exported to Claude'
assert_contains "$mock_external_env" 'CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3' 'tool concurrency is exported to Claude'
assert_contains "$mock_external_env" 'ENABLE_TOOL_SEARCH=false' 'tool search flag is exported to Claude'
assert_eq '8' "${#mock_claude_args[@]}" 'claude argument count'
assert_eq '--settings' "$mock_claude_args[1]" 'gateway settings flag'
assert_eq \
  '{"env":{"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":"","DISABLE_AUTOUPDATER":"1","DISABLE_FEEDBACK_COMMAND":"1","DISABLE_ERROR_REPORTING":"1","DISABLE_TELEMETRY":"1"}}' \
  "$mock_claude_args[2]" \
  'gateway settings preserve nonessential traffic opt-outs while allowing discovery'
assert_eq '--model' "$mock_claude_args[3]" 'model flag'
assert_eq 'gpt-5.6-sol' "$mock_claude_args[4]" 'model value'
assert_eq '--effort' "$mock_claude_args[5]" 'forwarded effort option'
assert_eq 'medium' "$mock_claude_args[6]" 'forwarded effort value'
assert_eq '--print' "$mock_claude_args[7]" 'forwarded print option'
assert_eq 'fallback prompt' "$mock_claude_args[8]" 'forwarded argument boundary'

export XDG_STATE_HOME="$test_root/custom-state"
xdg_token_file="$XDG_STATE_HOME/cliproxyapi/client-token"
mkdir -p "${xdg_token_file:h}"
print -r -- 'xdg-token-one' > "$xdg_token_file"
claudex 'first XDG call'
assert_eq 'xdg-token-one' "$mock_anthropic_auth_token" 'XDG state token takes precedence'

print -r -- 'xdg-token-two' > "$xdg_token_file"
claudex 'second XDG call'
assert_eq 'xdg-token-two' "$mock_anthropic_auth_token" 'token is reread for every invocation'
assert_eq 'second XDG call' "$mock_claude_args[5]" 'second invocation arguments'

rm -f -- "$xdg_token_file"
missing_error="$test_root/missing-token.err"
if claudex ignored 2> "$missing_error"; then
  print -ru2 -- 'not ok: claudex succeeds without a token file'
  exit 1
fi
assert_contains "$(<"$missing_error")" \
  "missing or empty CLIProxyAPI client token: $xdg_token_file" \
  'missing token error identifies the expected path'
assert_eq '3' "$mock_claude_calls" 'missing token does not invoke claude'

: > "$xdg_token_file"
empty_error="$test_root/empty-token.err"
if claudex ignored 2> "$empty_error"; then
  print -ru2 -- 'not ok: claudex succeeds with an empty token file'
  exit 1
fi
assert_contains "$(<"$empty_error")" \
  "missing or empty CLIProxyAPI client token: $xdg_token_file" \
  'empty token error identifies the expected path'
assert_eq '3' "$mock_claude_calls" 'empty token does not invoke claude'

mock_bin="$test_root/bin"
mock_log="$test_root/cli-proxy-api.log"
mkdir -p "$mock_bin"
export CLIPROXYAPI_MOCK_LOG="$mock_log"
export CLIPROXYAPI_MOCK_CREDENTIAL="$test_root/mock-credential"
export CLIPROXYAPI_HELPERS_MOCK_MODE=1
ln -s "$repo_root/ai/cliproxyapi/tests/cliproxyapi_helpers.test.zsh" "$mock_bin/cli-proxy-api"
export PATH="$mock_bin:$PATH"

cliproxyapi-login-claude --no-browser 'claude callback'
cliproxyapi-login-codex --no-browser 'codex callback'

expected_login_log="--config
$HOME/.cli-proxy-api/config.yaml
--claude-login
--no-browser
claude callback
---
--config
$HOME/.cli-proxy-api/config.yaml
--codex-login
--no-browser
codex callback
---"
assert_eq "$expected_login_log" "$(<"$mock_log")" 'login helpers use the config, login mode, and forwarded arguments'
assert_eq '600' "$(stat -c '%a' "$CLIPROXYAPI_MOCK_CREDENTIAL")" 'login helpers protect generated credentials'

print 'ok'
