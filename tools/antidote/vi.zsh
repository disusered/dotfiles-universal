# Undo/Redo
bindkey -M vicmd 'u' undo
bindkey -M vicmd '^R' redo

# Paste in vim mode with p
vi-append-x-selection () { RBUFFER=$(clippaste </dev/null)$RBUFFER; }
zle -N vi-append-x-selection
bindkey -a 'p' vi-append-x-selection
