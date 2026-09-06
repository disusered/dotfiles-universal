-- Make Steam Friends windows always open as floating
hl.window_rule({
  match = { title = "Friends List" },
  float = true,
})

-- Make Gamescope windows always open as floating
hl.window_rule({
  match = { class = "gamescope" },
  name = "gamescope_global",
  float = true,
  center = true,
  border_size = 0,
  rounding = 0,
  no_shadow = true,
  workspace = "current",
  fullscreen = true,
  immediate = false,
  animation = "none",
})
if hl.plugin.hyprbars then
  hl.window_rule({
    match = { class = "gamescope" },
    ["hyprbars:no_bar"] = true,
  })
end
