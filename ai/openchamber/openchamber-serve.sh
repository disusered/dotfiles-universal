#!/usr/bin/env bash
set -euo pipefail

export PATH="/home/carlos/.local/bin:/home/carlos/.opencode/bin:$PATH"
eval "$(/home/carlos/.local/bin/mise activate bash)"

export OPENCHAMBER_UI_PASSWORD="$(cat ~/.config/openchamber/.ui-password)"
export OPENCODE_JWT_SECRET="$(cat ~/.config/openchamber/.jwt-secret)"
export OPENCODE_CONFIG_DIR="$HOME/.config/opencode"

exec openchamber serve --host 127.0.0.1 --port 3014 --foreground
