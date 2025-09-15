local wezterm = require("wezterm")
local act = wezterm.action

local module = {}

function module.apply_to_config(config)
	local win_home = wezterm.home_dir

	local workspaces = {
		-- { id = "~", label = "Home (Fedora)", domain = "WSL:Fedora" },
		{ id = "~/.dotfiles", label = "Dotfiles (Ubuntu)", domain = "WSL:Ubuntu" },
		{ id = "~/.dotfiles", label = "Dotfiles (Fedora)", domain = "WSL:Fedora" },
		{
			id = "~/Learning/leetcode",
			label = "LeetCode",
			domain = "WSL:Fedora",
			args = { "zsh", "-lic", "nvim leetcode.nvim" },
		},
		-- { id = "~/Development/se", label = "CRI (Ubuntu)", domain = "WSL:Ubuntu" },
		{ id = "~/Development/cosmiq", label = "Cosmiq (Fedora)", domain = "WSL:Fedora" },
		{ id = "~/Development/Brillai.API", label = "Brillai (Fedora)", domain = "WSL:Fedora" },
		-- { id = "~/Learning/", label = "Exercism (Ubuntu)", domain = "WSL:Ubuntu" },
		{ id = win_home .. "/.dotfiles", label = "Dotfiles (Windows)", domain = "local" },
		-- { id = win_home .. "/Documents/Development/Brillai.API", label = "Brillai (Windows)", domain = "local" },
	}

	-- Create a separate list for the InputSelector's choices.
	-- This table ONLY contains the `id` and `label` fields, as required by Wezterm.
	local choices = {}
	for _, ws in ipairs(workspaces) do
		table.insert(choices, { id = ws.id, label = ws.label })
	end

	local keys = {
		{
			key = "N",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(function(window, pane)
				window:perform_action(
					act.InputSelector({
						action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
							-- The lookup logic remains the same. We use the original `workspaces`
							-- table to find the full data, including the domain.
							local selected_ws
							for _, ws in ipairs(workspaces) do
								if ws.id == id and ws.label == label then
									selected_ws = ws
									break
								end
							end

							if selected_ws then
								local spawn_config = {
									label = "Workspace: " .. selected_ws.label,
									domain = { DomainName = selected_ws.domain },
									cwd = selected_ws.id,
								}

								-- Add args if they exist
								if selected_ws.args then
									spawn_config.args = selected_ws.args
								end

								inner_window:perform_action(
									act.SwitchToWorkspace({
										name = selected_ws.label,
										spawn = spawn_config,
									}),
									inner_pane
								)
							end
						end),
						title = "Choose Workspace",
						-- Use the sanitized `choices` table here.
						choices = choices,
						fuzzy = true,
						fuzzy_description = "Restore a saved workspace",
					}),
					pane
				)
			end),
		},
	}

	config.keys = require("utilities")._concat(config.keys, keys)

	return config
end

return module
