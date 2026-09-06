-- Power button triggers shutdown
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'"))

-- Close all open scratchpads or modal tools
hl.on("hyprland.shutdown", function()
  hl.exec_cmd("~/.local/bin/hyprshutdown-wrapper")
end)
