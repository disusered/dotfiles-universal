_openviking_codex_cli_config() {
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

if [ -f "$HOME/.openviking/openviking-repo/examples/codex-memory-plugin/setup-helper/wrapper.sh" ]; then
  . "$HOME/.openviking/openviking-repo/examples/codex-memory-plugin/setup-helper/wrapper.sh"

  if whence -w _openviking_codex_exec >/dev/null 2>&1; then
    functions -c _openviking_codex_exec _openviking_codex_exec_upstream

    _openviking_codex_exec() {
      local _ov_conf
      _ov_conf="$(_openviking_codex_cli_config "$PWD")"
      OPENVIKING_CLI_CONFIG_FILE="$_ov_conf" _openviking_codex_exec_upstream "$@"
    }
  fi
fi
