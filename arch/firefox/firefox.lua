-- Make windows always open as floating
hl.window_rule({
  match = { title = "Picture-in-Picture" },
  float = true,
})

-- Make windows persistent across workspaces
hl.window_rule({
  match = { title = "Picture-in-Picture" },
  pin = true,
})
