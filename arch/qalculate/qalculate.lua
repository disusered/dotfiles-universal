hl.window_rule({
  match = { class = "qalculate-gtk" },
  name = "calculator",
  workspace = "special:calculator",
  float = true,
  center = true,
})

hl.bind("SUPER + C", hl.dsp.exec_cmd("~/.local/bin/hyprspace toggle calculator"))
hl.bind("SUPER + CTRL + C", hl.dsp.exec_cmd("~/.local/bin/hyprspace raw calculator"))
