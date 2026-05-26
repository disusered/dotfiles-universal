if command -v jj &>/dev/null && (( $+functions[compdef] )); then
  source <(COMPLETE=zsh jj)
fi
