local wezterm = require("wezterm")
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")

local module = {}

function module.apply_to_config(config)
	local keys = {
		-- Workspace switcher key bindings
		{
			key = "w",
			mods = "LEADER",
			action = workspace_switcher.switch_workspace(),
		},
		{
			key = "W",
			mods = "LEADER|SHIFT",
			action = workspace_switcher.switch_to_prev_workspace(),
		},
		{
			key = "Tab",
			mods = "LEADER",
			action = workspace_switcher.switch_to_prev_workspace(),
		},
	}

	-- Merge the provided keys with the existing ones in the config
	config.keys = require("utilities")._concat(config.keys, keys)

	return config
end

return module
