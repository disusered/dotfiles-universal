-- Floating, centered, persistent password prompt
hl.window_rule({
  match = { class = "1Password" },
  name = "1Password",
  float = true,
  center = true,
  pin = true,
  stay_focused = true,
  animation = "slide top",
})

--##################
--## KEYBINDINGS ###
--##################


hl.bind("SUPER + P", hl.dsp.exec_cmd("app2unit 1password.desktop"))
