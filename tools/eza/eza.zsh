
if (( $+commands[eza] )); then
  typeset enable_autocd=0
  typeset -ag eza_params

  eza_params=(
    '--git' '--icons' '--group' '--group-directories-first'
    '--time-style=long-iso' '--color-scale=all' '--hyperlink'
  )

  [[ ! -z $_EZA_PARAMS ]] && eza_params=($_EZA_PARAMS)

  alias ls='eza $eza_params'
  alias l='eza --git-ignore $eza_params'
  alias ll='eza --all --header --long $eza_params'
  alias llm='eza --all --header --long --sort=modified $eza_params'
  alias la='eza -lbhHigUmuSa'
  alias lx='eza -lbhHigUmuSa@'
  alias lt='eza --tree $eza_params'
  alias tree='eza --tree $eza_params'

  [[ "$AUTOCD" = <-> ]] && enable_autocd="$AUTOCD"
  if [[ "$enable_autocd" == "1" ]]; then
    # Function for cd auto list directories
    →auto-eza() { command eza; }
    typeset -g chpwd_functions
    [[ $chpwd_functions[(r)→auto-eza] == →auto-eza ]] || chpwd_functions=( →auto-eza $chpwd_functions )
  fi
fi
