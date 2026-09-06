hl.window_rule({
  match = { initial_class = "r:^chrome-.*-Default$", title = "Claude for Chrome" },
  name = "Claude Prompt",
  float = true,
  center = true,
  animation = "slide top",
})

hl.window_rule({
  match = { class = "claude_modal" },
  name = "claude_modal",
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.7)",
  center = true,
  group = "set",
  workspace = "special:ai",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "claude_modal" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.bind("SUPER + grave", hl.dsp.exec_cmd("app2unit -- ~/.local/bin/hyprspace toggle ai"))
hl.bind("SUPER + SHIFT + grave", hl.dsp.exec_cmd("app2unit -- ~/.local/bin/hyprspace spawn ai"))
hl.bind("SUPER + CTRL + grave", hl.dsp.exec_cmd("app2unit -- ~/.local/bin/hyprspace raw ai"))
