#!/bin/sh

exec "${XDG_DATA_HOME:-$HOME/.local/share}/piper-tts/1.7.0/bin/python" -m piper "$@"
