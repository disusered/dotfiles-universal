local module = {}
local wezterm = require("wezterm")

function module.apply_to_config(config)
	-- Color scheme configuration - sets the terminal color theme
	config.color_scheme = "Catppuccin Mocha" -- or Macchiato, Frappe, Latte

	-- Window appearance settings - removes title bar but keeps resize capability
	config.window_decorations = "RESIZE"

	-- Window padding configuration - removes all padding around terminal content
	config.window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	}

	-- WSL (Windows Subsystem for Linux) domain configuration
	-- Defines available WSL distributions for multi-environment workflows
	config.wsl_domains = {
		{
			name = "WSL:Ubuntu", -- Domain identifier for Ubuntu WSL
			distribution = "Ubuntu", -- WSL distribution name
			default_cwd = "/home/carlos", -- Starting directory in Ubuntu
		},
		{
			name = "WSL:Fedora", -- Domain identifier for Fedora WSL
			distribution = "FedoraLinux-42", -- WSL distribution name
		},
	}

	-- SSH domain configuration for remote server connections
	config.ssh_domains = {
		{
			name = "SSH:Ubuntu", -- SSH domain identifier
			remote_address = "127.0.0.1", -- Target server address (localhost)
			username = "carlos", -- SSH username
			connect_automatically = true, -- Auto-connect on startup
			multiplexing = "None", -- SSH connection multiplexing setting
			assume_shell = "Posix", -- Shell type assumption for compatibility
		},
	}

	-- Default domain setting - specifies which environment opens by default
	config.default_domain = "local"

	-- Default program configuration - sets PowerShell 7 as the default shell on Windows
	config.default_prog = { "pwsh.exe" }

	-- Launch menu configuration - defines quick-access menu items
	config.launch_menu = {
		{
			label = "CRI SSH (Staging)", -- Menu item display name
			domain = { DomainName = "WSL:Fedora" }, -- Run in Fedora WSL environment
			args = { "ssh", "ser_stage" }, -- Command to execute
		},
	}

	-- Platform-specific configuration - adds PowerShell option on Windows
	if wezterm.target_triple == "x86_64-pc-windows-msvc" then
		table.insert(config.launch_menu, {
			label = "PowerShell 7", -- Menu item for PowerShell
			domain = { DomainName = "local" }, -- Run in local Windows environment
			args = { "pwsh.exe", "-NoLogo" }, -- PowerShell without startup logo
		})
	end
end

return module
