_openviking_claude_cli_config() {
  local _ov_pwd="${1:-$PWD}"
  local _ov_xbol_root="$HOME/Development/XBOL"

  if [ -n "${OPENVIKING_CLI_CONFIG_FILE:-}" ]; then
    print -r -- "$OPENVIKING_CLI_CONFIG_FILE"
    return
  fi

  case "$_ov_pwd" in
    "$_ov_xbol_root"| "$_ov_xbol_root"/*)
      print -r -- "$HOME/.openviking/ovcli-xbol.conf"
      ;;
    *)
      print -r -- "$HOME/.openviking/ovcli.conf"
      ;;
  esac
}

_openviking_claude_exec() {
  local _ov_conf
  _ov_conf="$(_openviking_claude_cli_config "$PWD")"
  OPENVIKING_CLI_CONFIG_FILE="$_ov_conf" command claude "$@"
}

claude() {
  _openviking_claude_exec "$@"
}
