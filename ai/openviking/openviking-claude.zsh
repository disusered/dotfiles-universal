_openviking_claude_cli_config() {
  local _ov_pwd="${1:-$PWD}"
  local _ov_xbol_root="$HOME/Development/XBOL"
  local _ov_iteramind_root="$HOME/Development/ITERAMIND"

  if [ -n "${OPENVIKING_CLI_CONFIG_FILE:-}" ]; then
    print -r -- "$OPENVIKING_CLI_CONFIG_FILE"
    return
  fi

  case "$_ov_pwd" in
    "$_ov_iteramind_root"| "$_ov_iteramind_root"/*)
      print -r -- "$HOME/.openviking/ovcli-iteramind.conf"
      ;;
    "$_ov_xbol_root"| "$_ov_xbol_root"/*)
      print -r -- "$HOME/.openviking/ovcli-xbol.conf"
      ;;
    *)
      print -r -- "$HOME/.openviking/ovcli.conf"
      ;;
  esac
}

# Print the identity fields of an ovcli config as NAME=value lines, skipping
# any field that is absent or empty. The hooks read the config file directly,
# but the MCP server does not: the plugin's .mcp.json interpolates
# ${OPENVIKING_ACCOUNT} / ${OPENVIKING_USER} into request headers, so without
# these in the env the MCP connection lands on a different account than the
# hooks. An empty value is worse than a missing one — an empty bearer token is
# still an Authorization header — so empty fields are dropped, not exported.
_openviking_claude_identity() {
  local _ov_conf="${1:-}"

  [ -n "$_ov_conf" ] && [ -f "$_ov_conf" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  jq -r '
    {
      OPENVIKING_URL:     (.url     // ""),
      OPENVIKING_API_KEY: (.api_key // ""),
      OPENVIKING_ACCOUNT: (.account // ""),
      OPENVIKING_USER:    (.user    // "")
    }
    | to_entries[]
    | select(.value != "")
    | "\(.key)=\(.value)"
  ' "$_ov_conf" 2>/dev/null
}

_openviking_claude_exec() {
  local _ov_conf
  _ov_conf="$(_openviking_claude_cli_config "$PWD")"

  local -a _ov_env=("OPENVIKING_CLI_CONFIG_FILE=$_ov_conf")
  local _ov_line _ov_name
  while IFS= read -r _ov_line; do
    [ -n "$_ov_line" ] || continue
    _ov_name="${_ov_line%%=*}"
    # A caller-set value wins, matching the OPENVIKING_CLI_CONFIG_FILE guard
    # in _openviking_claude_cli_config.
    [ -n "${(P)_ov_name:-}" ] && continue
    _ov_env+=("$_ov_line")
  done < <(_openviking_claude_identity "$_ov_conf")

  # `env` rather than a prefix assignment so the list stays dynamic, and it
  # runs the binary rather than re-entering the claude() function below.
  env "${_ov_env[@]}" claude "$@"
}

claude() {
  _openviking_claude_exec "$@"
}
