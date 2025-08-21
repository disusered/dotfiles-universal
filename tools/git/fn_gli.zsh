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
    nvim fugitive://$(git rev-parse --show-toplevel)/.git//$(git rev-parse $shas)
  elif [ "$k" = ctrl-i ]; then
    git rebase --interactive $shas
    break
  elif [ "$k" = ctrl-c ]; then
    echo $shas | tr -d '\n' | clipcopy
    break
  elif [ "$k" = ctrl-r ]; then
    git reset --hard $shas
  else
    for sha in $shas; do
      git show --color=always $sha
    done
  fi
done

