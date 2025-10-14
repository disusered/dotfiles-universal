#!/bin/bash

# --- Configuration ---
RECORDER_PATH=$(which wf-recorder)
VIDEO_DIR="$HOME/Videos"
TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
FILE_PATH="$VIDEO_DIR/${TIMESTAMP}_wlrecorder.mp4"

# Build the command and its arguments in an array to avoid quoting issues.
RECORDER_CMD_ARRAY=(
  "$RECORDER_PATH"
  -a
  -f "$FILE_PATH"
  -c libx264
  -m mp4
  -p crf=24
  -p preset=ultrafast
)

# --- Optional: Waybar Integration ---
update_waybar() {
  pkill -RTMIN+8 waybar
}

# --- Main Logic ---
PGREP_PATTERN="$RECORDER_PATH -a -f"

if pgrep -f "$PGREP_PATTERN" >/dev/null; then
  # --- STOP RECORDING ---
  pkill -f -INT "$PGREP_PATTERN"
  notify-send "Screen Recording Stopped" "File saved to $VIDEO_DIR"
  update_waybar
else
  # --- START RECORDING ---
  mkdir -p "$VIDEO_DIR"

  if [ "$1" == "--region" ]; then
    # --- Region Recording ---
    GEOMETRY=$(slurp -d -c "#88c0d0" -b "#3b4252BF" -w 2)
    if [ -n "$GEOMETRY" ]; then
      notify-send "Screen Recording" "Starting region recording..."
      # Execute by expanding the array and adding the geometry flag. No `sh -c` needed.
      app2unit -- "${RECORDER_CMD_ARRAY[@]}" -g "$GEOMETRY"
      update_waybar
    else
      notify-send "Screen Recording" "Cancelled."
    fi
  else
    # --- Full-screen Recording ---
    MONITORS_INFO=$(hyprctl monitors -j)
    MONITOR_COUNT=$(echo "$MONITORS_INFO" | jq 'length')

    if [ "$MONITOR_COUNT" -le 1 ]; then
      MONITOR_NAME=$(echo "$MONITORS_INFO" | jq -r '.[0].name')
      notify-send "Screen Recording" "Recording monitor: $MONITOR_NAME"
      app2unit -- "${RECORDER_CMD_ARRAY[@]}" -o "$MONITOR_NAME"
      update_waybar
    else
      MONITOR_LIST=$(echo "$MONITORS_INFO" | jq -r '.[].name')
      CHOSEN_MONITOR=$(echo -e "$MONITOR_LIST" | rofi -dmenu -p "Select monitor to record")

      if [ -n "$CHOSEN_MONITOR" ]; then
        notify-send "Screen Recording" "Recording monitor: $CHOSEN_MONITOR"
        app2unit -- "${RECORDER_CMD_ARRAY[@]}" -o "$CHOSEN_MONITOR"
        update_waybar
      else
        notify-send "Screen Recording" "Cancelled."
      fi
    fi
  fi
fi
