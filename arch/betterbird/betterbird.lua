-- Keep mail synchronized without opening a window at session startup.
hl.on("hyprland.start", function()
  hl.exec_cmd("app2unit -s b -- betterbird")
end)
