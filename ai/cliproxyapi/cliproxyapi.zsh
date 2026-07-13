cliproxyapi-login-claude() {
  (
    umask 077
    command cli-proxy-api \
      --config "$HOME/.cli-proxy-api/config.yaml" \
      --claude-login \
      "$@"
  )
}

cliproxyapi-login-codex() {
  (
    umask 077
    command cli-proxy-api \
      --config "$HOME/.cli-proxy-api/config.yaml" \
      --codex-login \
      "$@"
  )
}

claudex() {
  local _cliproxyapi_state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  local _cliproxyapi_token_file="$_cliproxyapi_state_home/cliproxyapi/client-token"
  local _cliproxyapi_gateway_settings='{"env":{"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":"","DISABLE_AUTOUPDATER":"1","DISABLE_FEEDBACK_COMMAND":"1","DISABLE_ERROR_REPORTING":"1","DISABLE_TELEMETRY":"1"}}'
  local _cliproxyapi_token

  if [[ ! -r "$_cliproxyapi_token_file" || ! -s "$_cliproxyapi_token_file" ]]; then
    print -ru2 -- "claudex: missing or empty CLIProxyAPI client token: $_cliproxyapi_token_file"
    return 1
  fi

  _cliproxyapi_token=$(<"$_cliproxyapi_token_file")
  if [[ -z "$_cliproxyapi_token" ]]; then
    print -ru2 -- "claudex: missing or empty CLIProxyAPI client token: $_cliproxyapi_token_file"
    return 1
  fi

  ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
    ANTHROPIC_AUTH_TOKEN="$_cliproxyapi_token" \
    CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
    CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol \
    CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
    CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 \
    ENABLE_TOOL_SEARCH=false \
    claude \
      --settings "$_cliproxyapi_gateway_settings" \
      --model gpt-5.6-sol \
      "$@"
}
