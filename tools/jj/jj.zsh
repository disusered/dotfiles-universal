if command -v jj &>/dev/null && (( $+functions[compdef] )); then
  source <(COMPLETE=zsh jj)
fi

alias jj='noglob jj'

# jj aliases
# No `jb`: that is the JetBrains CLI (~/.dotnet/tools/jb).
alias j='jj'
alias jl='jj log'
alias jla='jj la'
alias js='jj st'
alias jd='jj diff'
alias jn='jj new'
alias jf='jj f'
alias jp='jj p'
