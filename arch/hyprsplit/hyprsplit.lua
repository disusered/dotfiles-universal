local hs = require("hyprsplit")
hs.config({ num_workspaces = 6 })

for workspace = 1, 6 do
    hl.bind("SUPER + " .. workspace, hs.dsp.focus({ workspace = workspace }))
    hl.bind("SUPER + SHIFT + " .. workspace,
        hs.dsp.window.move({ workspace = workspace, follow = true }))
end

hl.bind("SUPER + TAB", hs.dsp.focus({ workspace = "m+1" }))
hl.bind("SUPER + SHIFT + TAB", hs.dsp.focus({ workspace = "m-1" }))
hl.bind("SUPER + n", hs.dsp.focus({ workspace = "empty" }))
hl.bind("XF86LaunchA", hl.dsp.exec_cmd("app2unit -- pypr-client fetch_client_menu"),
    { repeating = true, locked = true })
