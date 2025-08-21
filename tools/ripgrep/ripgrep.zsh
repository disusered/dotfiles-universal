# Configuration path
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"

# Text search in file content
alias rg='rgi'
alias ag='rgi'

# Search with ripgrep and pipe to delta for a side-by-side view
# Usage: rgi [rg_flags] <search_term>
# Example: rgi -C 2 my_search_term
rgi() {
  if [ $# -eq 0 ]; then
    echo "Usage: rg [rg_flags] <search_term>" >&2
    return 1
  fi
  $HOMEBREW_PREFIX/bin/rg --json -C 2 "$@" | delta
}
