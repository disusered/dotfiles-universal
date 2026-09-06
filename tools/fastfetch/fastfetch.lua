hl.window_rule({
  match = { class = "fastfetch_scratch" },
  name = "fastfetch_scratch",
  float = true,
  size = "734 625",
  move = "((monitor_w-window_w)/2) (-window_h)",
  animation = "slide top",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "fastfetch_scratch" },
    ["hyprbars:no_bar"] = true,
  })
end

-- Super+Pause - mirrors Windows system info shortcut
hl.bind("SUPER + Home", hl.dsp.exec_cmd("app2unit -- pypr-client toggle fastfetch"))
