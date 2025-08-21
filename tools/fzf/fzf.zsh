# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Default FZF options
# Colors from https://github.com/catppuccin/fzf
export FZF_DEFAULT_OPTS=" \
--layout=reverse \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
