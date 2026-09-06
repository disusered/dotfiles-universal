hl.window_rule({
  match = { class = "lazygit_modal" },
  name = "lazygit_modal",
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.7)",
  center = true,
  group = "set",
  workspace = "special:lazygit",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "lazygit_modal" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.bind("SUPER + G", hl.dsp.exec_cmd("~/.local/bin/hyprspace toggle lazygit"))
hl.bind("SUPER + CTRL + G", hl.dsp.exec_cmd("~/.local/bin/hyprspace raw lazygit"))
