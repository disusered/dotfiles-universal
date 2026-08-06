export PATH=/home/carlos/.opencode/bin:$PATH

_openviking_opencode_account() {
  local _ov_pwd="${1:-$PWD}"
  local _ov_xbol_root="$HOME/Development/XBOL"
  local _ov_iteramind_root="$HOME/Development/ITERAMIND"

  case "$_ov_pwd" in
    "$_ov_iteramind_root"| "$_ov_iteramind_root"/*)
      print -r -- "iteramind-dev"
      ;;
    "$_ov_xbol_root"| "$_ov_xbol_root"/*)
      print -r -- "xbol"
      ;;
    *)
      print -r -- "local-dev"
      ;;
  esac
}

opencode() {
  if [ -n "${OPENVIKING_ACCOUNT:-}" ] || [ -n "${OPENVIKING_USER:-}" ] || [ -n "${OPENVIKING_AGENT_ID:-}" ]; then
    command opencode "$@"
    return
  fi

  local _ov_account
  _ov_account="$(_openviking_opencode_account "$PWD")"
  OPENVIKING_ACCOUNT="$_ov_account" \
    OPENVIKING_USER="carlos" \
    OPENVIKING_AGENT_ID="$_ov_account" \
    command opencode "$@"
}

opencode-init() {
  op read "op://Personal/GLM Coding Plan - OpenCode/password" > ~/.config/opencode/.zai-key
  chmod 600 ~/.config/opencode/.zai-key
}
