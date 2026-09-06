-- Activate (invoke default action) on the oldest notification
hl.bind("SUPER + A", hl.dsp.exec_cmd("makoctl invoke; makoctl dismiss"))

-- Dismiss the oldest notification
hl.bind("SUPER + backspace", hl.dsp.exec_cmd("makoctl dismiss"))

-- Dismiss all notifications at once
hl.bind("SUPER + SHIFT + backspace", hl.dsp.exec_cmd("makoctl dismiss -a"))
