-- Maximize RDP connection windows, but not the Remmina client itself.
-- Hyprland uses RE2, which does not support negative lookahead. Use its native
-- regex negation prefix so this rule can be evaluated without an error flood.
hl.window_rule({
  match = { class = "org.remmina.Remmina", title = "negative:^Remmina Remote Desktop Client$" },
  name = "remmina_connection",
  maximize = true,
  tile = true,
})
