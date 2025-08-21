
if (( $+commands[eza] )); then
  typeset enable_autocd=0

  # Default parameters for eza
  export _EZA_PARAMS=('--git' '--group' '--group-directories-first' '--time-style=long-iso' '--hyperlinks')

  alias ls='eza'
  alias l='eza --git-ignore'
  alias ll='eza --all --header --long'
  alias llm='eza --all --header --long --sort=modified'
  alias la='eza -lbhHigUmuSa'
  alias lx='eza -lbhHigUmuSa@'
  alias lt='eza --tree'
  alias tree='eza --tree'

  [[ "$AUTOCD" = <-> ]] && enable_autocd="$AUTOCD"
  if [[ "$enable_autocd" == "1" ]]; then
    # Function for cd auto list directories
    →auto-eza() { command eza; }
    typeset -g chpwd_functions
    [[ $chpwd_functions[(r)→auto-eza] == →auto-eza ]] || chpwd_functions=( →auto-eza $chpwd_functions )
  fi
fi
