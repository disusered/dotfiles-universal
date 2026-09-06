hl.bind("CTRL + SHIFT + ALT + Escape", hl.dsp.exec_cmd("app2unit -- pypr-client toggle abtop"))

hl.window_rule({
  match = { class = "abtop_scratch" },
  name = "abtop_scratch",
  float = true,
  size = "(monitor_w*0.7) (monitor_h*0.7)",
  move = "((monitor_w-window_w)/2) (-window_h)",
  animation = "slide top",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "abtop_scratch" },
    ["hyprbars:no_bar"] = true,
  })
end
