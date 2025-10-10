#!/bin/sh
# ytsearch: search and select youtube video links (no api).
#           (many thanks to https://github.com/pystardust/ytfzf)

case "$1" in "-h" | "--help")
  echo "usage: ytsearch query..."
  exit 0
  ;;
esac

# Create temp directory for thumbnail cache
CACHE_DIR="${TMPDIR:-/tmp}/ytsearch_cache_$$"
mkdir -p "$CACHE_DIR"
trap 'rm -rf "$CACHE_DIR"' EXIT

# Fetch and parse results, save raw JSON for description extraction
raw_json=$(curl -s -G "https://www.youtube.com/results" --data-urlencode "search_query=$*" |
  tr -d '\n' |
  sed -e 's#^.*var \+ytInitialData *=##' -e 's#;</script>.*##')

echo "$raw_json" >"$CACHE_DIR/results.json"

# Parse results for display
results=$(echo "$raw_json" |
  jq -r '..
    | .videoRenderer?
    | select(.)
    | [.title.runs[0].text[:80], (.lengthText.simpleText//"N/A"), (.shortViewCountText.simpleText//"N/A"), (.publishedTimeText.simpleText//"N/A"), .longBylineText.runs[0].text, .videoId]
    | @tsv' |
  column -s "$(printf '\t')" -t)

# Select with fzf and preview
echo "$results" | fzf \
  --with-nth=..-2 \
  --preview-window='right:50%' \
  --preview='
    video_id=$(echo {} | awk "{print \$NF}")
    thumb_path="'"$CACHE_DIR"'/${video_id}.jpg"
    
    if [ ! -f "$thumb_path" ]; then
      curl -s "https://img.youtube.com/vi/${video_id}/hqdefault.jpg" -o "$thumb_path" 2>/dev/null
    fi
    
    echo {}
    echo
    echo
    kitty +kitten icat --clear --transfer-mode=file "$thumb_path" 2>/dev/null
    
    printf "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
    
    jq -r ".. | .videoRenderer? | select(.videoId == \"${video_id}\") | .detailedMetadataSnippets[]?.snippetText.runs[]?.text" "'"$CACHE_DIR"'/results.json" 2>/dev/null | tr -d "\n" | fold -s -w 80
  ' |
  awk '{ print "https://www.youtube.com/watch?v="$NF }'
