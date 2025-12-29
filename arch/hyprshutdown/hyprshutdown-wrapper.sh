#!/bin/bash
# Kill all scratchpad windows (SIGKILL bypasses prompts)
hyprctl dispatch killwindow class:btop_scratch
hyprctl dispatch killwindow class:fastfetch_scratch
hyprctl dispatch killwindow class:fonts_scratch
hyprctl dispatch killwindow class:org.pulseaudio.pavucontrol
hyprctl dispatch killwindow class:org.pipewire.Helvum

# Run hyprshutdown
hyprshutdown "$@"
