hl.window_rule({
  match = { class = "org.pulseaudio.pavucontrol" },
  name = "pavucontrol",
  float = true,
  size = "760 760",
  move = "(monitor_w-760-35) 55",
  animation = "slide right",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "org.pulseaudio.pavucontrol" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.window_rule({
  match = { class = "org.pipewire.Helvum" },
  name = "helvum",
  float = true,
  size = "1080 760",
  move = "(monitor_w-1080-35) 55",
  animation = "slide right",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "org.pipewire.Helvum" },
    ["hyprbars:no_bar"] = true,
  })
end
