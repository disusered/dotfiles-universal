-- Quick Format citation dialog floats
hl.window_rule({
  match = { title = "Zotero Quick Format" },
  name = "Zotero Quick Format",
  float = true,
  center = true,
})

--##################
--## KEYBINDINGS ###
--##################


hl.bind("SUPER + Backspace", hl.dsp.exec_cmd("zotero"))
