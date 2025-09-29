local wezterm = require("wezterm")

-- My configs
local base = require("base")
local fonts = require("fonts")
local tabbar = require("tabbar")
local tmux = require("tmux")
local keys = require("keys")
local workspaces = require("workspaces")
local sessions = require("sessions")
local uri = require("uri")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Apply configs
base.apply_to_config(config)
tmux.apply_to_config(config)
fonts.apply_to_config(config)
keys.apply_to_config(config)
tabbar.apply_to_config(config, {
	modules = {
		-- Change the leader icon
		leader = { icon = wezterm.nerdfonts.cod_diff_modified },
		-- Shown when the pane is zoomed
		zoom = { enabled = true },
		-- Disable pane information
		pane = { enabled = false },
		-- I don't need to know the current user
		username = { enabled = false },
		-- I don't need to know the current hostname
		hostname = { enabled = false },
	},
})
workspaces.apply_to_config(config)
sessions.apply_to_config(config)
uri.apply_to_config(config)

config.switch_to_last_active_tab_when_closing_tab = true

-- Finally, return the configuration to wezterm:
return config
