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

# Git Log Interactive
# https://gist.github/junepunn/f4fca918e937e6bf5bad
function gli() {
  local out shas sha q k
  while out=$(
      git l $@ |
      fzf --ansi --no-sort --reverse --multi --query="$q" \
          --print-query --expect=ctrl-d,ctrl-c,ctrl-i,ctrl-r,ctrl-s,ctrl-p,ctrl-v --toggle-sort=\`); do
    q=$(head -1 <<< "$out")
    k=$(head -2 <<< "$out" | tail -1)
    shas=$(sed '1,2d;s/^[^a-z0-9]*//;/^$/d' <<< "$out" | awk '{print $1}' | tr '\n' ' ')
    shas=${shas% }
    [ -z "$shas" ] && continue
    if [ "$k" = ctrl-d ]; then
      GIT_PAGER='delta --pager="less -RX -c -+F"' git show $shas
      break
    elif [ "$k" = ctrl-s ]; then
      echo -n "$shas" | pbcopy
      notify-send "Git Log" "Copied to clipboard:\n$shas"
    elif [ "$k" = ctrl-p ]; then
      # Capture both standard output and error from the cherry-pick command
      pick_output=$(git cherry-pick $shas 2>&1)
      # Store the exit code immediately
      local exit_code=$?

      if [ $exit_code -eq 0 ]; then
        notify-send "Git Cherry-Pick Success" "$pick_output"
      else
        notify-send -u critical "Git Cherry-Pick Failed" "$pick_output"
      fi
    elif [ "$k" = ctrl-i ]; then
      git rebase --interactive $shas
      break
    elif [ "$k" = ctrl-r ]; then
      git reset --hard $shas
      break
    elif [ "$k" = ctrl-v ]; then
      for sha in $shas; do
        git difftool --no-symlinks --dir-diff $sha^..$sha
      done
      break
    elif [ "$k" = ctrl-c ]; then
      break
    else
      for sha in $shas; do
        GIT_PAGER='delta --pager="less -RX -c -+F"' git show $sha
      done
    fi
  done
}
