hl.window_rule({
  match = { class = "clipse_scratch" },
  name = "clipse_scratch",
  float = true,
  size = "720 720",
  center = true,
  animation = "slide top",
  workspace = "special:clipboard",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "clipse_scratch" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.bind("SUPER + V", hl.dsp.exec_cmd("~/.local/bin/hyprspace toggle clipboard"))
hl.bind("SUPER + CTRL + V", hl.dsp.exec_cmd("~/.local/bin/hyprspace raw clipboard"))
