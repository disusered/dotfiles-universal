hl.window_rule({
  match = { title = "dictate_feedback" },
  name = "dictate_feedback",
  float = true,
  size = "640 128",
  move = "((monitor_w-window_w)/2) 35",
  pin = true,
  border_size = 0,
  rounding = 8,
  no_shadow = true,
  animation = "slide top",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { title = "dictate_feedback" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.bind("CTRL + SPACE", hl.dsp.exec_cmd("app2unit -- dictate begin"))
hl.bind("CTRL + SPACE", hl.dsp.exec_cmd("/home/carlos/.cargo/bin/dictate end"), { release = true })
hl.bind("CTRL + SPACE", hl.dsp.exec_cmd("/home/carlos/.cargo/bin/dictate heartbeat"), { repeating = true })
hl.bind("CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("app2unit -- dictate cancel"))
