#!/bin/bash

MONITOR_COUNT=$(hyprctl monitors -j | jq length)

if [ "$MONITOR_COUNT" -eq 1 ]; then
    echo "Single monitor detected. Switching to dual monitor profile..."
    hyprctl keyword monitor "eDP-1,preferred,0x0,1"
    hyprctl keyword monitor "HDMI-A-1,preferred,1920x0,1"
else
    echo "Multiple monitors detected. Switching to single monitor profile..."
    hyprctl keyword monitor "HDMI-A-1,disable"
    hyprctl keyword monitor "eDP-1,preferred,auto,1"
fi
