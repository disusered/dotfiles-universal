local module = {}
local wezterm = require("wezterm")

function module.apply_to_config(config)
	-- Set the color scheme
	config.color_scheme = "Catppuccin Mocha" -- or Macchiato, Frappe, Latte

	-- Disable window decorations i.e. the title bar and borders
	config.window_decorations = "RESIZE"

	-- No padding around the window
	config.window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	}

	-- Set the WSL domains
	config.wsl_domains = {
		{
			name = "WSL:Ubuntu",
			distribution = "Ubuntu",
			default_cwd = "/home/carlos",
		},
		{
			name = "WSL:Fedora",
			distribution = "FedoraLinux-42",
		},
	}

	config.ssh_domains = {
		{
			name = "SSH:Ubuntu",
			remote_address = "127.0.0.1",
			username = "carlos",
			connect_automatically = true,
			multiplexing = "None",
			assume_shell = "Posix",
		},
	}

	-- Default domain is local (cmd.exe)
	config.default_domain = "local"

	-- PowerShell 7 by default on Windows
	config.default_prog = { "pwsh.exe" }

	config.launch_menu = {
		{
			label = "CRI SSH (Staging)",
			domain = { DomainName = "WSL:Ubuntu" },
			args = { "ssh", "ser_stage" },
		},
	}

	if wezterm.target_triple == "x86_64-pc-windows-msvc" then
		table.insert(config.launch_menu, {
			label = "PowerShell 7",
			domain = { DomainName = "local" },
			args = { "pwsh.exe", "-NoLogo" },
		})
	end
end

return module
