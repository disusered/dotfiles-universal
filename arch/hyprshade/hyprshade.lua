hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd HYPRLAND_INSTANCE_SIGNATURE")
end)
