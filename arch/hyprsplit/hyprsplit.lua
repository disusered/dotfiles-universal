local hs = require("hyprsplit")
-- Rank connected outputs so unplugged displays do not reserve workspace ranges.
-- Recompute on each lookup, including the plugin's hotplug event handlers.
local monitor_range_new = hs.MonitorRange.new
function hs.MonitorRange:new(monitor)
    local monitors = hl.get_monitors()
    local priority = { ["HDMI-A-1"] = 1, ["HDMI-A-2"] = 2 }
    table.sort(monitors, function(a, b)
        local a_rank, b_rank = priority[a.name] or 3, priority[b.name] or 3
        if a_rank ~= b_rank then
            return a_rank < b_rank
        end
        return a.name < b.name
    end)
    hs.monitor_priority_list = {}
    for _, connected in ipairs(monitors) do
        table.insert(hs.monitor_priority_list, connected.name)
    end
    return monitor_range_new(self, monitor)
end
hs.config({ num_workspaces = 6 })
hl.on("monitor.removed", function()
    hs.ensure_good_workspaces()
end)

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
