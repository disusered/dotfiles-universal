#!/usr/bin/env sh

cfg_bin="${CFG_TMUX_BRIDGE_CFG_BIN:-$HOME/.local/bin/cfg}"
bridge=false

if [ "${CFG_TMUX_BRIDGE:-}" = "abtop-kitty" ]; then
    bridge=true
elif [ -r "/proc/$PPID/cmdline" ]; then
    if tr '\000' '\n' <"/proc/$PPID/cmdline" 2>/dev/null | sed 's#.*/##' | grep -qx abtop; then
        bridge=true
    fi
elif [ -r "/proc/$PPID/comm" ]; then
    read -r parent_name <"/proc/$PPID/comm"
    if [ "$parent_name" = "abtop" ]; then
        bridge=true
    fi
fi

if [ "$bridge" = "true" ]; then
    exec "$cfg_bin" tmux "$@"
fi

exec /usr/bin/tmux "$@"
