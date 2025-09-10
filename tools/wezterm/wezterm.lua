local wezterm = require("wezterm")

-- My configs
local init = require("init")
local fonts = require("fonts")
local tabbar = require("tabbar")
local tmux = require("tmux")
local keys = require("keys")
local workspaces = require("workspaces")
local sessions = require("sessions")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Hyperlinks
local function is_shell(foreground_process_name)
	local shell_names = { "bash", "zsh", "fish", "sh", "ksh", "dash" }
	local process = string.match(foreground_process_name, "[^/\\]+$") or foreground_process_name
	for _, shell in ipairs(shell_names) do
		if process == shell then
			return true
		end
	end
	return false
end

wezterm.on("open-uri", function(window, pane, uri)
	local editor = "nvim"

	-- Only act on file:// URIs when not in an alternate screen
	if not (uri:find("^file:") == 1 and not pane:is_alt_screen_active()) then
		return
	end

	local domain_name = pane:get_domain_name()

	-- Case 1: Pane is running in WSL (Unchanged)
	if domain_name and domain_name:find("WSL") then
		local url = wezterm.url.parse(uri)
		local edit_cmd = url.fragment and editor .. " +" .. url.fragment .. ' "$_f"' or editor .. ' "$_f"'
		local cmd = '_f="'
			.. url.file_path
			.. '"; { test -d "$_f" && explorer.exe "$(wslpath -w "$_f")"; } '
			.. '|| { test "$(file --brief --mime-type "$_f" | cut -d/ -f1 || true)" = "text" && '
			.. edit_cmd
			.. ' || explorer.exe "$(wslpath -w "$_f")"; }'
		pane:send_text(cmd .. "\r")
		return false

	-- Case 2: Pane is native Windows (e.g., PowerShell, cmd) -- FINAL VERSION
	elseif wezterm.target_triple:find("windows") then
		-- Manually strip the prefix from the non-standard URI
		local win_path = uri:gsub("^file://", "")

		-- Run the reliable PowerShell Test-Path command silently in the background
		local success, stdout, stderr = wezterm.run_child_process({
			"powershell.exe",
			"-NoProfile",
			"-Command",
			string.format("Test-Path -LiteralPath '%s' -PathType Container", win_path),
		})

		-- If the test ran successfully, check its output
		if success and stdout:find("True") then
			-- It's a directory. Open it silently with explorer.
			wezterm.run_child_process({ "explorer.exe", win_path })
			return false -- We handled it.
		else
			-- It's a file (or the test failed). Send the nvim command to the pane.
			local edit_cmd_parts = { editor .. ".exe", win_path }
			pane:send_text(wezterm.shell_join_args(edit_cmd_parts) .. "\r")
			return false -- We handled it.
		end

	-- Case 3: Pane is native Linux/macOS (Unchanged)
	else
		local url = wezterm.url.parse(uri)
		if is_shell(pane:get_foreground_process_name()) then
			local success, stdout, _ = wezterm.run_child_process({
				"file",
				"--brief",
				"--mime-type",
				url.file_path,
			})
			if success then
				if stdout:find("directory") then
					pane:send_text(wezterm.shell_join_args({ "cd", url.file_path }) .. "\r")
					pane:send_text(wezterm.shell_join_args({
						"/usr/bin/ls",
						"-a",
						"-p",
						"--group-directories-first",
					}) .. "\r")
					return false
				end

				if stdout:find("text") then
					if url.fragment then
						pane:send_text(wezterm.shell_join_args({
							editor,
							"+" .. url.fragment,
							url.file_path,
						}) .. "\r")
					else
						pane:send_text(wezterm.shell_join_args({ editor, url.file_path }) .. "\r")
					end
					return false
				end
			end
		end
		return
	end
end)

-- Apply configs
init.apply_to_config(config)
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

-- Finally, return the configuration to wezterm:
return config
