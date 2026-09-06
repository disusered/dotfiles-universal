-- Make VirtualBox settings windows always open as floating and centered
hl.window_rule({
  match = { class = "VirtualBoxVM", initial_title = "r:.* - Settings$" },
  float = true,
})
hl.window_rule({
  match = { class = "VirtualBoxVM", initial_title = "r:.* - Settings$" },
  center = true,
})
hl.window_rule({
  match = { class = "VirtualBoxVM", initial_title = "VirtualBox - Preferences" },
  float = true,
})
hl.window_rule({
  match = { class = "VirtualBoxVM", initial_title = "VirtualBox - Preferences" },
  center = true,
})

-- Virtual keyboard
hl.window_rule({
  match = { class = "VirtualBoxVM", initial_title = "r:.* - Soft Keyboard$" },
  float = true,
})
hl.window_rule({
  match = { class = "VirtualBoxVM", initial_title = "r:.* - Soft Keyboard$" },
  center = true,
})
