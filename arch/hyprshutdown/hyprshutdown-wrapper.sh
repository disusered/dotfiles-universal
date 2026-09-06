#!/bin/bash
# TODO: Update for foot.
# Here's an idea: each dot file links a zsh configuration that takes adds itself
# to an environment variable similar to how we can compose $PATH

# Kill all scratchpad windows (SIGKILL bypasses prompts)
hyprctl dispatch "hl.dsp.window.kill({window='class:btop_scratch'})"
hyprctl dispatch "hl.dsp.window.kill({window='class:clipse_scratch'})"
hyprctl dispatch "hl.dsp.window.kill({window='class:fastfetch_scratch'})"
hyprctl dispatch "hl.dsp.window.kill({window='class:cfg_scratch'})"
hyprctl dispatch "hl.dsp.window.kill({window='class:fonts_scratch'})"
hyprctl dispatch "hl.dsp.window.kill({window='class:cfg_wallpaper_scratch'})"
hyprctl dispatch "hl.dsp.window.kill({window='class:org.pulseaudio.pavucontrol'})"
hyprctl dispatch "hl.dsp.window.kill({window='class:org.pipewire.Helvum'})"

# Safely unmount and power-off removable drives (see Arch Wiki: USB storage devices).
# --detach calls udisksctl power-off per drive so heads park / SSDs flush.
command -v udiskie-umount >/dev/null && udiskie-umount --all --detach 2>/dev/null || true
