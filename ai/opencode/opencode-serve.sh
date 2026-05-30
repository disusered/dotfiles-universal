#!/usr/bin/env bash
export PATH="/home/carlos/.local/bin:$PATH"
eval "$(/home/carlos/.local/bin/mise activate bash)"
exec opencode serve --port 3014 --hostname 127.0.0.1
