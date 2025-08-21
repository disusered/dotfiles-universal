# Search with ripgrep and pipe to delta for a side-by-side view
# Usage: rgi [rg_flags] <search_term>
# Example: rgi -C 2 my_search_term
if [ $# -eq 0 ]; then
  echo "Usage: rg [rg_flags] <search_term>" >&2
  return 1
fi
$HOMEBREW_PREFIX/bin/rg --json -C 2 "$@" | delta
