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
