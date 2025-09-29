local wezterm = require("wezterm")

local module = {}

-- Helper function to detect if the foreground process is a shell
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

-- Configure URI handling for different platforms
function module.apply_to_config(config)
	-- Set up URI event handler for file:// links
	wezterm.on("open-uri", function(window, pane, uri)
		local editor = "nvim"

		-- Only act on file:// URIs when not in an alternate screen
		if not (uri:find("^file:") == 1 and not pane:is_alt_screen_active()) then
			return
		end

		local domain_name = pane:get_domain_name()

		-- Case 1: Pane is running in WSL
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

		-- Case 2: Pane is native Windows (e.g., PowerShell, cmd)
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

		-- Case 3: Pane is native Linux/macOS
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
end

return module
