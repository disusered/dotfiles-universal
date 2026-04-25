#!/usr/bin/env bash
# Patch a game's compatibility tool mapping in Steam's config.vdf.
#
# Usage: steam-set-compat-tool.sh <app_id> <tool_name> [game_label]
#
# - Replaces an existing CompatToolMapping entry for the app id, preserving
#   tabs and the surrounding sub-block layout.
# - Inserts a fresh "<app_id>" { name; config; priority } block before
#   CompatToolMapping's closing brace when the app id is absent.
# - Refuses to touch the file while Steam is running, since Steam rewrites
#   config.vdf on shutdown and would clobber our changes.
# - Exits 0 with a warning when config.vdf cannot be found or Steam is
#   running, so Rotz installs are not aborted by a missing / busy Steam.
# - Exits non-zero only if "CompatToolMapping" itself is absent — in that
#   case the user must set any compat tool once via Steam UI to materialize
#   the section before automation can touch it.

set -e

APP_ID="${1:?app_id required}"
TOOL_NAME="${2:?tool_name required}"
GAME_LABEL="${3:-$APP_ID}"

CONFIG="$HOME/.local/share/Steam/config/config.vdf"

if [ ! -f "$CONFIG" ]; then
  echo "Warning: Steam config.vdf not found. Set compat tool manually in Steam:"
  echo "  $GAME_LABEL ($APP_ID) -> $TOOL_NAME"
  exit 0
fi

if pgrep -x steam >/dev/null 2>&1; then
  echo "Warning: Steam is running. Close Steam before installing to set compat tool."
  echo "  Compat tool to set manually: $GAME_LABEL ($APP_ID) -> $TOOL_NAME"
  exit 0
fi

if ! grep -q '"CompatToolMapping"' "$CONFIG"; then
  echo "Error: CompatToolMapping section not found in $CONFIG"
  echo "Set any compat tool once via Steam UI (right-click game ->"
  echo "Properties -> Compatibility) to materialize the section, then re-run."
  exit 1
fi

awk -v app="\"$APP_ID\"" -v tool="$TOOL_NAME" '
  # Enter the CompatToolMapping section.
  !in_ctm && /^[[:space:]]*"CompatToolMapping"[[:space:]]*$/ {
    in_ctm=1; ctm_open=1; print; next
  }
  in_ctm && ctm_open && /^[[:space:]]*\{/ {
    ctm_depth=1; ctm_open=0; print; next
  }

  # Inside CTM: detect the per-app sub-block start.
  in_ctm && !in_app && $0 ~ "^[[:space:]]*" app "[[:space:]]*$" {
    in_app=1; app_open=1; found=1; print; next
  }
  in_app && app_open && /^[[:space:]]*\{/ {
    app_depth=1; app_open=0; print; next
  }

  # Replace fields inside the matched app block.
  in_app {
    if (/"name"/) {
      sub(/"name"[[:space:]]*"[^"]*"/, "\"name\"\t\t\"" tool "\"")
    }
    if (/"config"/) {
      sub(/"config"[[:space:]]*"[^"]*"/, "\"config\"\t\t\"\"")
    }
    if (/"priority"/) {
      sub(/"priority"[[:space:]]*"[^"]*"/, "\"priority\"\t\t\"250\"")
    }
  }

  # Track app block depth and exit it on its closing brace.
  in_app && /\{/ && !app_open { app_depth++ }
  in_app && /^[[:space:]]*\}/ {
    app_depth--
    if (app_depth==0) { in_app=0; print; next }
  }

  # Track CTM depth (only when not inside an app block) and insert on close.
  in_ctm && !in_app && /\{/ && !ctm_open { ctm_depth++ }
  in_ctm && !in_app && /^[[:space:]]*\}/ {
    ctm_depth--
    if (ctm_depth==0) {
      if (!found) {
        match($0, /^[[:space:]]*/)
        indent = substr($0, 1, RLENGTH) "\t"
        print indent app
        print indent "{"
        print indent "\t\"name\"\t\t\"" tool "\""
        print indent "\t\"config\"\t\t\"\""
        print indent "\t\"priority\"\t\t\"250\""
        print indent "}"
      }
      in_ctm=0
    }
  }

  { print }
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

echo "Steam compatibility tool set for $GAME_LABEL ($APP_ID): $TOOL_NAME"
