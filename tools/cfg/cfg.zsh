cfg-wallpaper-pick() {
    emulate -L zsh
    local dir
    dir="$(cfg wallpaper --get source_dir 2>/dev/null)"
    if [[ -z "$dir" ]]; then
        echo "source_dir not set; run: cfg wallpaper --set source_dir=<dir>" >&2
        return 1
    fi
    dir="${dir/#\~/$HOME}"
    if [[ ! -d "$dir" ]]; then
        echo "source_dir is not a directory: $dir" >&2
        return 1
    fi
    local chosen
    chosen=$(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null \
        | fzf --preview 'kitten icat --clear --transfer-mode=memory --stdin=no --place=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0 {}' \
              --preview-window=right:60%) || return
    cfg wallpaper --set "path=$chosen" --apply
}
