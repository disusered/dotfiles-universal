#!/usr/bin/env bash
# Install Skyrim SE mods from verified archives, per games/skyrim-special-edition/mods/manifest.tsv.
#
#   skyrim-install-mods --scan      hash whatever is in the staging dir and print manifest rows
#   skyrim-install-mods --dry-run   say what would happen, touch nothing
#   skyrim-install-mods             verify and install
#
# Why this shape:
#
# There is no Nexus Premium on this account, so nothing can be downloaded
# unattended — the archives are fetched by hand in a browser and dropped in the
# staging dir. That makes the archive itself the only thing we can be sure of,
# so the manifest is *derived from the files* with --scan rather than
# transcribed from mod pages. Hashes then mean something: they are what was
# actually installed and played, on a known game build.
#
# Nothing is downloaded, and nothing is installed that does not match its
# recorded hash.

set -uo pipefail

APP_ID=489830
MODULE_DIR="${SKYRIM_MODULE_DIR:-$HOME/.dotfiles/games/skyrim-special-edition}"
MANIFEST="${SKYRIM_MOD_MANIFEST:-$MODULE_DIR/mods/manifest.tsv}"
STAGING="${SKYRIM_MOD_STAGING:-$HOME/Downloads/skyrim-mods}"
CONFIG_DIR="${SKYRIM_MOD_CONFIG:-$MODULE_DIR/mods/config}"
STATE_DIR="${SKYRIM_MOD_STATE:-$HOME/.local/state/skyrim-mods}"

MODE=install
case "${1:-}" in
  --scan)    MODE=scan ;;
  --dry-run) MODE=dryrun ;;
  --help|-h) sed -n '2,20p' "$0"; exit 0 ;;
  "")        ;;
  *)         echo "unknown option: $1" >&2; exit 2 ;;
esac

die() { echo "Error: $*" >&2; exit 1; }
note() { echo "  $*"; }

# Directory names that are part of the game's own layout. A single top-level
# folder with one of these names is the payload, never a wrapper to descend
# through — Address Library and SSE Display Tweaks both ship exactly one
# top-level `SKSE/`, and stripping it puts their plugins in Data/Plugins/ where
# SKSE will never look for them.
IS_GAME_DIR='^(data|skse|interface|meshes|textures|scripts|sounds|music|video|seq|strings|shadersfx|lodsettings|source|grass|dyndolod|netscriptframework|tools|calientetools|bashtags|docs|fomod)$'

# Other mods do wrap their payload in a named folder — SKSE's own archive is
# `skse64_2_02_06/` holding skse64_loader.exe, the runtime dll and Data/.
# Copying that verbatim would drop a build-named directory into the game root
# and leave the loader unfound, so descend through it.
strip_wrapper() {
  local listing=$1 top
  top=$(awk -F/ 'NF{print $1}' <<<"$listing" | sort -u)
  [ "$(wc -l <<<"$top")" -eq 1 ] || { printf '%s' "$listing"; return; }
  if [[ ${top,,} =~ $IS_GAME_DIR ]]; then printf '%s' "$listing"; return; fi
  grep -v "^$top\$" <<<"$listing" | sed "s|^$top/||"
}

# Rename directories inside $1 to match the casing of directories that already
# exist under $2.
#
# Mod authors package for Windows, where the filesystem is case-insensitive and
# Interface/ and interface/ are the same folder. Here they are not. Quest Journal
# Overhaul ships lowercase `interface/` while every other mod ships `Interface/`,
# so a plain copy produced *both* — and Wine resolves an exact match before it
# falls back to a case-insensitive search, so a lookup for Interface\questjournal.swf
# found the capitalised directory, missed the file, and the mod silently did
# nothing. Same story one level down for translations/ against Translations/.
#
# Loop until stable rather than in one pass: renaming a parent invalidates the
# paths already collected for its children.
align_case() {
  local src=$1 dst=$2 changed=1
  while [ "$changed" = 1 ]; do
    changed=0
    while IFS= read -r rel; do
      local parent name dstparent existing
      parent=${rel%/*}; [ "$parent" = "$rel" ] && parent=""
      name=${rel##*/}
      dstparent="$dst${parent:+/$parent}"
      [ -d "$dstparent" ] || continue
      [ -e "$dstparent/$name" ] && continue
      existing=$(find "$dstparent" -mindepth 1 -maxdepth 1 -type d -iname "$name" \
                   -printf '%f\n' 2>/dev/null | head -1)
      [ -n "$existing" ] && [ "$existing" != "$name" ] || continue
      mv "$src/$rel" "$src${parent:+/$parent}/$existing"
      note "case: $rel -> ${parent:+$parent/}$existing (matching Data/)"
      changed=1
      break
    done < <(cd "$src" && find . -mindepth 1 -type d -printf '%P\n' | sort)
  done
}

command -v 7z >/dev/null || die "7z not found (pacman -S p7zip)"

if ! LIB=$("$MODULE_DIR/../lib/steam-find-app-path.sh" "$APP_ID" 2>/dev/null); then
  die "Skyrim SE ($APP_ID) not found in any Steam library"
fi
# SKYRIM_GAME_DIR overrides the resolved install; used by the test harness so a
# dry run of the real thing can never scribble into the live game directory.
GAME_DIR="${SKYRIM_GAME_DIR:-$LIB/steamapps/common/Skyrim Special Edition}"
DATA_DIR="$GAME_DIR/Data"
[ -d "$GAME_DIR" ] || die "game directory missing: $GAME_DIR"

BUILD_ID=$(awk -F'"' '/"buildid"/{print $4}' "$LIB/steamapps/appmanifest_$APP_ID.acf" 2>/dev/null)

mkdir -p "$STAGING"

# ── scan ──────────────────────────────────────────────────────────────────
# Emit manifest rows for every archive sitting in the staging dir, with the
# real hash and a guess at the destination based on what the archive contains.
if [ "$MODE" = scan ]; then
  shopt -s nullglob nocaseglob
  archives=("$STAGING"/*.{7z,zip,rar})
  shopt -u nullglob nocaseglob
  [ ${#archives[@]} -gt 0 ] || die "no archives in $STAGING"

  echo "# scanned $(date +%Y-%m-%d) against game buildid $BUILD_ID" >&2
  printf 'enabled\tname\tarchive\tsha256\tdestination\tarchive_root\tplugins\tsource_url\n'
  for a in "${archives[@]}"; do
    base=$(basename "$a")
    sum=$(sha256sum "$a" | cut -d' ' -f1)
    raw=$(7z l -ba -slt "$a" 2>/dev/null | sed -n 's/^Path = //p')
    listing=$(strip_wrapper "$raw")

    # A top-level Data/ (or an .esp/.esm/.bsa at the root) means Data-relative;
    # a top-level .dll or skse64_loader.exe means it belongs beside the exe.
    dest=data
    if grep -qiE '^(skse64_loader\.exe|[^/]*\.dll)$' <<<"$listing"; then
      dest=root
    fi

    # FOMOD archives are interactive installers: they carry several mutually
    # exclusive variants (AE vs SE) plus a shared Required/ tree, and only a
    # human can say which applies. Flag it rather than dumping all of them.
    root_hint=
    if grep -qiE '(^|/)fomod/' <<<"$raw"; then
      root_hint="FOMOD-PICK-SUBDIRS"
      echo "note: $base is a FOMOD installer — set archive_root to the subdirs to install," >&2
      echo "      semicolon-separated. Candidates:" >&2
      awk -F/ 'NF>1{print $1"/"$2}' <<<"$raw" | sort -u | sed 's/^/        /' >&2
    fi

    plugins=$(grep -oiE '[^/]+\.(esp|esm|esl)$' <<<"$listing" | sort -u | paste -sd, -)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      yes "${base%.*}" "$base" "$sum" "$dest" "$root_hint" "${plugins:-}" "TODO"
  done
  exit 0
fi

# ── install ───────────────────────────────────────────────────────────────
[ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST (run --scan to bootstrap it)"

installed=0 skipped=0 missing=0
declare -a ORDERED_PLUGINS=()

# Read the manifest a line at a time and split on tabs with mapfile.
#
# `while IFS=$'\t' read -r a b c ...` looks right and is not: tab is an IFS
# whitespace character, so bash collapses runs of tabs into one delimiter and
# every empty column shifts the rest of the row left. A mod with no plugins
# silently got its source_url read as its plugin name, and the load order came
# out with a "*TODO" entry pointing at a plugin that does not exist.
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*|enabled$'\t'*) continue ;; esac
  mapfile -t -d $'\t' F < <(printf '%s' "$line")
  enabled=${F[0]-}   name=${F[1]-}     archive=${F[2]-}    sha256=${F[3]-}
  destination=${F[4]-} archive_root=${F[5]-} plugins=${F[6]-} source_url=${F[7]-}
  [ "$enabled" = no ] && continue

  # Collect the load order from every enabled row, before any check that can
  # skip the row.
  #
  # This used to happen only for rows that actually installed, which quietly
  # made the load order depend on what happened to be sitting in the staging
  # dir. Archives are transient — they get cleared out after an install — so a
  # later run with an empty staging dir would rewrite Plugins.txt from the two
  # or three mods still staged and *disable everything else*, USSEP included.
  # The manifest is the declaration of what is installed; a missing archive
  # says nothing about whether the mod is in Data/. Skyrim ignores entries for
  # plugins that do not exist, so listing one costs nothing.
  if [ -n "${plugins:-}" ]; then
    IFS=',' read -ra ps <<<"$plugins"
    for p in "${ps[@]}"; do [ -n "$p" ] && ORDERED_PLUGINS+=("$p"); done
  fi

  if [ "$archive_root" = FOMOD-PICK-SUBDIRS ]; then
    echo "SKIP  $name: FOMOD archive with no archive_root chosen"
    note "re-run --scan to list candidate subdirs, then set archive_root"
    skipped=$((skipped + 1)); continue
  fi

  path="$STAGING/$archive"
  if [ ! -f "$path" ]; then
    echo "MISSING  $name"
    note "expected $path"
    note "download: ${source_url:-<no url recorded>}"
    missing=$((missing + 1))
    continue
  fi

  actual=$(sha256sum "$path" | cut -d' ' -f1)
  if [ -n "$sha256" ] && [ "$sha256" != "$actual" ]; then
    echo "HASH MISMATCH  $name"
    note "expected $sha256"
    note "actual   $actual"
    note "refusing to install; re-download or update the manifest deliberately"
    skipped=$((skipped + 1))
    continue
  fi
  [ -n "$sha256" ] || note "$name: no hash recorded, installing unverified"

  case "$destination" in root) target="$GAME_DIR" ;; data) target="$DATA_DIR" ;;
    *) echo "SKIP  $name: bad destination '$destination'"; skipped=$((skipped+1)); continue ;;
  esac

  if [ "$MODE" = dryrun ]; then
    echo "WOULD INSTALL  $name -> $target"
  else
    tmp=$(mktemp -d)
    if ! 7z x -y -o"$tmp" "$path" >/dev/null 2>&1; then
      echo "SKIP  $name: could not unpack"
      rm -rf "$tmp"; skipped=$((skipped + 1)); continue
    fi
    # Work out which directories inside the archive to copy from. An explicit
    # archive_root wins (that is how a FOMOD's chosen variants are named, and
    # more than one may apply — Engine Fixes needs Required/ *and* AE/).
    roots=()
    if [ -n "$archive_root" ]; then
      IFS=';' read -ra rs <<<"$archive_root"
      for r in "${rs[@]}"; do
        r=${r#"${r%%[![:space:]]*}"}          # trim leading space
        [ -n "$r" ] || continue
        if [ -d "$tmp/$r" ]; then roots+=("$tmp/$r")
        else echo "SKIP  $name: archive_root '$r' not in archive"; fi
      done
      [ ${#roots[@]} -gt 0 ] || { rm -rf "$tmp"; skipped=$((skipped+1)); continue; }
    else
      # Descend through a single named wrapper folder (see strip_wrapper), but
      # never through one that is game structure in its own right.
      src=$tmp
      shopt -s nullglob dotglob
      entries=("$tmp"/*)
      shopt -u nullglob dotglob
      if [ ${#entries[@]} -eq 1 ] && [ -d "${entries[0]}" ]; then
        base=$(basename "${entries[0]}")
        [[ ${base,,} =~ $IS_GAME_DIR ]] || src=${entries[0]}
      fi
      roots=("$src")
    fi

    mkdir -p "$target"

    # Record which files this archive owns, before copying them.
    #
    # There is no mod manager here, so nothing else knows what belongs to what.
    # Without this list, removing one mod means verifying the whole game through
    # Steam and reinstalling every other mod on top — which is the wrong answer
    # for a mod set that is now large enough to want individual mods gone.
    mkdir -p "$STATE_DIR"
    : > "$STATE_DIR/$archive.files"

    for r in "${roots[@]}"; do
      # Unwrap a Data/ folder only for data-destined mods. Root-destined
      # archives (SKSE ships skse64_loader.exe *and* a Data/Scripts alongside
      # it) must be copied from their own root, or the loader is silently left
      # behind — the game then starts vanilla with no hint why.
      s=$r
      if [ "$destination" = data ]; then
        for d in "$r"/Data "$r"/data; do
          [ -d "$d" ] && { s=$d; break; }
        done
      fi
      # Paths are recorded destination-prefixed, so a remover knows whether a
      # name is Data-relative or beside the exe without re-reading the manifest.
      align_case "$s" "$target"
      (cd "$s" && find . -type f -printf '%P\n') \
        | sed "s|^|$destination/|" >> "$STATE_DIR/$archive.files"
      cp -a "$s"/. "$target"/
    done
    rm -rf "$tmp"
    echo "INSTALLED  $name -> ${target#"$LIB"/}"
  fi
  installed=$((installed + 1))
done < "$MANIFEST"

# ── config overlay ────────────────────────────────────────────────────────
# Mods ship their own .ini/.json/.toml defaults inside the archive, and the loop
# above copies them verbatim — so every re-run silently reset whatever had been
# tuned in game, and the other machine always started from mod defaults. The
# repo owns these files instead: mods/config/ mirrors the two destinations,
# mods/config/root/ landing beside SkyrimSE.exe and mods/config/data/ in Data/.
#
# Applied in one pass *after* every archive is unpacked, deliberately. Doing it
# per mod would let an archive installed later in the manifest overwrite an
# earlier mod's config, which is the whole bug being fixed here.
configured=0
for scope in root data; do
  src="$CONFIG_DIR/$scope"
  [ -d "$src" ] || continue
  case "$scope" in root) target="$GAME_DIR" ;; data) target="$DATA_DIR" ;; esac
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if [ "$MODE" = dryrun ]; then
      echo "WOULD APPLY CONFIG  $scope/$rel"
    else
      mkdir -p "$target/$(dirname "$rel")"
      cp -a "$src/$rel" "$target/$rel"
    fi
    configured=$((configured + 1))
  done < <(cd "$src" && find . -type f -printf '%P\n' | sort)
done
[ "$configured" -eq 0 ] || echo "Config overlay: $configured file(s) from ${CONFIG_DIR#"$HOME"/}"

# ── load order ────────────────────────────────────────────────────────────
# Skyrim SE marks enabled plugins with a leading '*'. The file is Plugins.txt
# with a capital P; the filesystem is case-sensitive even though Wine is not,
# so the name is written exactly as the game creates it.
#
# Only .esp files need to be listed. Skyrim SE loads every ESM- and ESL-flagged
# plugin it finds in Data/ whether or not Plugins.txt mentions it, which is why
# writing only the manifest's plugins does not disable the DLC, _ResourcePack.esl
# or the Creation Club content. Verified by reading the plugin list back out of a
# save: all four cc* plugins and _ResourcePack.esl load while Plugins.txt names
# nothing but USSEP and SkyUI. USSEP hard-masters all five, so this is load-
# bearing — do not "fix" it by listing them here.
PLUGINS_TXT="${SKYRIM_PLUGINS_TXT:-$LIB/steamapps/compatdata/$APP_ID/pfx/drive_c/users/steamuser/AppData/Local/Skyrim Special Edition/Plugins.txt}"
if [ "$MODE" != dryrun ] && [ ${#ORDERED_PLUGINS[@]} -gt 0 ] && [ -d "$(dirname "$PLUGINS_TXT")" ]; then
  {
    echo "# Written by skyrim-install-mods from mods/manifest.tsv."
    echo "# Order follows the manifest; '*' marks a plugin as enabled."
    for p in "${ORDERED_PLUGINS[@]}"; do echo "*$p"; done
  } > "$PLUGINS_TXT"
  echo "Load order written: ${#ORDERED_PLUGINS[@]} plugin(s) -> Plugins.txt"
fi

echo
echo "installed $installed, skipped $skipped, missing $missing (game buildid $BUILD_ID)"
[ "$missing" -eq 0 ] || note "drop the missing archives in $STAGING and re-run"
exit 0
