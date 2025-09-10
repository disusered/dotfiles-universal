local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

function module.apply_to_config(config)
	local keys = {
		-- Shift+Enter to send literal Enter for Claude Code
		{ key = "Enter", mods = "SHIFT", action = wezterm.action({ SendString = "\x1b\r" }) },
		-- Add key binding for naming the current tab
		{
			key = "A",
			mods = "LEADER|SHIFT",
			action = act.PromptInputLine({
				description = wezterm.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Blue" } },
					{ Text = "Enter new name for tab" },
				}),
				action = wezterm.action_callback(function(window, _, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
		-- Same but with a more modern binding
		{
			key = "E",
			mods = "CTRL|SHIFT",
			action = act.PromptInputLine({
				description = wezterm.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Blue" } },
					{ Text = "Enter new name for tab" },
				}),
				action = wezterm.action_callback(function(window, _, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
		-- Prompt for a name to use for a new workspace and switch to it.
		-- {
		-- 	key = "N",
		-- 	mods = "CTRL|SHIFT",
		-- 	action = act.PromptInputLine({
		-- 		description = wezterm.format({
		-- 			{ Attribute = { Intensity = "Bold" } },
		-- 			{ Foreground = { AnsiColor = "Blue" } },
		-- 			{ Text = "Enter name for new workspace" },
		-- 		}),
		-- 		action = wezterm.action_callback(function(window, pane, line)
		-- 			-- line will be `nil` if they hit escape without entering anything
		-- 			-- An empty string if they just hit enter
		-- 			-- Or the actual line of text they wrote
		-- 			if line then
		-- 				window:perform_action(
		-- 					act.SwitchToWorkspace({
		-- 						name = line,
		-- 					}),
		-- 					pane
		-- 				)
		-- 			end
		-- 		end),
		-- 	}),
		-- },
		-- Open the launcher
		{
			key = "P",
			mods = "CTRL|SHIFT",
			action = act.ShowLauncher,
		},
	}

	-- Merge the provided keys with the existing ones in the config
	config.keys = require("utilities")._concat(config.keys, keys)

	return config
end

return module
