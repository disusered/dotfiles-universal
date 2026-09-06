--##################
--## KEYBINDINGS ###
--##################

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --output-volume raise"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --output-volume lower"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --output-volume mute-toggle"), { repeating = true, locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --input-volume mute-toggle"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --brightness raise"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --brightness lower"), { repeating = true, locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --playerctl play-pause"), { repeating = true, locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("app2unit -- swayosd-client --monitor \"$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')\" --playerctl next"), { repeating = true, locked = true })
