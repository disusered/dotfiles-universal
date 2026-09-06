--##################
--## KEYBINDINGS ###
--##################


-- Take screenshot of window
hl.bind("SUPER + S", hl.dsp.exec_cmd("pgrep -x app2unit -- slurp || app2unit -- hyprshot -o ~/Pictures/Screenshots --freeze -m window"))

-- Take screenshot of region
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("pgrep -x app2unit -- slurp || app2unit -- hyprshot -o ~/Pictures/Screenshots --freeze -m region"))

-- Escape hatch: unfreeze desktop when hyprshot leaves hyprpicker running
hl.bind("SUPER + CTRL + S", hl.dsp.exec_cmd("pkill -x hyprpicker; pkill -x slurp; pkill -x hyprshot"))
