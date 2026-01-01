#!/bin/bash
# TODO: Update for foot.
# Here's an idea: each dot file links a zsh configuration that takes adds itself
# to an environment variable similar to how we can compose $PATH

# Kill all scratchpad windows (SIGKILL bypasses prompts)
hyprctl dispatch killwindow class:btop_scratch
hyprctl dispatch killwindow class:clipse_scratch
hyprctl dispatch killwindow class:fastfetch_scratch
hyprctl dispatch killwindow class:cfg_scratch
hyprctl dispatch killwindow class:fonts_scratch
hyprctl dispatch killwindow class:org.pulseaudio.pavucontrol
hyprctl dispatch killwindow class:org.pipewire.Helvum
