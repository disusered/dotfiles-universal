hl.on("hyprland.start", function()
  hl.exec_cmd("app2unit -s b -- cfg leds --apply")
end)

hl.window_rule({
  match = { class = "cfg_scratch" },
  name = "cfg_scratch",
  float = true,
  size = "1080 720",
  center = true,
  animation = "slide top",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "cfg_scratch" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.window_rule({
  match = { class = "fonts_scratch" },
  name = "fonts_scratch",
  float = true,
  size = "(monitor_w*0.25) (monitor_h*0.60)",
  center = true,
  animation = "popin",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "fonts_scratch" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.window_rule({
  match = { class = "cfg_wallpaper_scratch" },
  name = "cfg_wallpaper_scratch",
  float = true,
  size = "(monitor_w*0.60) (monitor_h*0.80)",
  center = true,
  animation = "popin",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "cfg_wallpaper_scratch" },
    ["hyprbars:no_bar"] = true,
  })
end

hl.bind("SUPER + comma", hl.dsp.exec_cmd("hyprctl clients -j | jq -e '.[] | select(.class == \"cfg_scratch\")' > /dev/null || app2unit -- kitty --class cfg_scratch cfg -i"))
