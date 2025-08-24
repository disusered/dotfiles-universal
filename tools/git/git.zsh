# Disable globbing with git
alias git='noglob git'

# Git aliases
alias g='git'
alias gl="gli"
alias gcp='git cherry-pick'
alias gs='git s'
alias gb='git b'
alias gbc='git bc'
alias gc='git c'
alias gca='git ca'
alias gcm='git cm'
alias ga='git a'
alias gp='git p'
alias gpf='git pf'
alias gd='git d'
alias gdt='git dt'
alias gm='git m'
alias gmt='git mt'
alias gf='git f'
alias gfm='git fm'
alias gr='git r'
alias gco='git co'

# Git log options
export GIT_LOG_STYLE_BASIC="%C(magenta bold)%h%C(reset) %C(auto)%d%C(reset) %s"
export GIT_LOG_STYLE_COMPLEX="%C(magenta bold)%h%C(reset) %C(blue bold)%aN%C(reset) %C(auto)%d%C(reset) %s %C(8)(%cr)%C(reset)"
export GIT_LOG_STYLE=$GIT_LOG_STYLE_COMPLEX

# Git Log Interactive
# https://gist.github/junegunn/f4fca918e937e6bf5bad
function gli() {
  local out shas sha q k
  while out=$(
      git l $@ --format=$GIT_LOG_STYLE |
      fzf --ansi --no-sort --reverse --multi --query="$q" \
          --print-query --expect=ctrl-d,ctrl-c,ctrl-i,ctrl-r --toggle-sort=\`); do
    q=$(head -1 <<< "$out")
    k=$(head -2 <<< "$out" | tail -1)
    shas=$(sed '1,2d;s/^[^a-z0-9]*//;/^$/d' <<< "$out" | awk '{print $1}')
    [ -z "$shas" ] && continue
    if [ "$k" = ctrl-d ]; then
      # Git will now handle the pager correctly via delta's new config
      git show $shas
      break
    elif [ "$k" = ctrl-i ]; then
      git rebase --interactive $shas
    elif [ "$k" = ctrl-c ]; then
      echo $shas | tr -d '\n' | pbcopy
      break
    elif [ "$k" = ctrl-r ]; then
      git reset --hard $shas
    else
      for sha in $shas; do
        git show $sha
      done
    fi
  done
}
