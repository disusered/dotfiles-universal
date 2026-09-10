codex-deepseek() (
  # Keep credentials out of shell tracing and the caller's environment.
  unsetopt xtrace
  local _deepseek_key
  _deepseek_key=$(command op read 'op://Personal/Deepseek/credential') || return
  if [[ -z "$_deepseek_key" ]]; then
    print -ru2 -- 'codex-deepseek: the Deepseek credential is empty'
    return 1
  fi

  DEEPSEEK_API_KEY="$_deepseek_key" codex \
    --profile deepseek \
    "$@"
)
