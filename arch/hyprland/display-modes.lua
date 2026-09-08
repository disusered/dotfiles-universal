-- Keep nwg-displays' layout, scale, rotation and other options, but pin the
-- known displays' modes so saving a layout cannot reset their refresh rates.
local modes = {
    ["Samsung Electric Company LS24D31x H9PXB00674"] = "1920x1080@75",
    ["Samsung Electric Company LS24D31x H9PXB00679"] = "1920x1080@75",
    ["Dell Inc. DELL S3422DWG G1C4KK3"] = "3440x1440@143.97",
}
local descriptions = {}
for _, monitor in ipairs(hl.get_monitors()) do
    descriptions[monitor.name] = monitor.description
end

local configured = {}
local config_dir = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr"
-- The main config already requires this file, which tracks it for reloads.
-- Read its monitor tables again in a private environment to amend only mode.
local environment = setmetatable({
    hl = setmetatable({ monitor = function(spec)
        local description = descriptions[spec.output] or spec.output:gsub("^desc:", "")
        local mode = modes[description]
        if mode then
            configured[description] = true
            if not spec.disabled then
                spec.mode = mode
                hl.monitor(spec)
            end
        end
    end }, { __index = hl }),
}, { __index = _G })
assert(loadfile(config_dir .. "/monitors.lua", "t", environment))()

-- Preserve the home mode when the saved nwg-displays layout contains only HDMI.
local dell = "Dell Inc. DELL S3422DWG G1C4KK3"
if not configured[dell] then
    hl.monitor({ output = "desc:" .. dell, mode = modes[dell], position = "0x0", scale = 1 })
end
