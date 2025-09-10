local wezterm = require("wezterm")

---@class bar.wezterm
local M = {}
local options = {}

local separator = package.config:sub(1, 1) == "\\" and "\\" or "/"
local plugin_dir = wezterm.plugin.list()[1].plugin_dir:gsub(separator .. "[^" .. separator .. "]*$", "")

---checks if the plugin directory exists
---@param path string
---@return boolean
local function directory_exists(path)
	local success, result = pcall(wezterm.read_dir, plugin_dir .. path)
	return success and result
end

---returns the name of the package, used when requiring modules
---@return string
local function get_require_path()
	local path = "httpssCssZssZsgithubsDscomsZsadriankarlensZsbarsDswezterm"
	local path_trailing_slash = "httpssCssZssZsgithubsDscomsZsadriankarlensZsbarsDsweztermsZs"
	return directory_exists(path_trailing_slash) and path_trailing_slash or path
end

package.path = package.path
	.. ";"
	.. plugin_dir
	.. separator
	.. get_require_path()
	.. separator
	.. "plugin"
	.. separator
	.. "?.lua"

local utilities = require("utilities")
local config = require("bar.config")
local tabs = require("bar.tabs")
local user = require("bar.user")
local paths = require("bar.paths")

---conforming to https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd
---@param c table: wezterm config object
---@param opts bar.options
M.apply_to_config = function(c, opts)
	-- make the opts arg optional
	if not opts then
		---@diagnostic disable-next-line: missing-fields
		opts = {}
	end

	-- combine user config with defaults
	options = config.extend_options(config.options, opts)

	local scheme = wezterm.color.get_builtin_schemes()[c.color_scheme]
	if scheme ~= nil then
		if c.colors ~= nil then
			scheme = utilities._merge(scheme, c.colors)
		end
		-- utilities.inspect(scheme.ansi)
		utilities.inspect(options.modules)
		local default_colors = {
			tab_bar = {
				background = "#181825",
				active_tab = {
					bg_color = "transparent",
					fg_color = scheme.ansi[8],
				},
				inactive_tab = {
					bg_color = "#11111b",
					fg_color = scheme.ansi[1],
				},
				new_tab = {
					bg_color = "#181825",
					fg_color = scheme.ansi[3],
				},
			},
		}
		c.colors = utilities._merge(scheme, default_colors)
	end

	-- make the plugin own these settings
	c.tab_bar_at_bottom = options.position == "bottom"
	c.use_fancy_tab_bar = false
	c.tab_max_width = options.max_width
end

wezterm.on("format-tab-title", function(tab, _, _, conf, _, _)
	local palette = conf.resolved_palette

	local index = tab.tab_index + 1
	local offset = #tostring(index) + #options.separator.left_icon + (2 * options.separator.space) + 2
	local title = index
		.. utilities._space(options.separator.left_icon, options.separator.space, nil)
		.. tabs.get_title(tab)

	local width = conf.tab_max_width - offset
	if #title > conf.tab_max_width then
		title = wezterm.truncate_right(title, width) .. "…"
	end

	local fg = palette.tab_bar.inactive_tab.fg_color
	local bg = palette.tab_bar.inactive_tab.bg_color
	if tab.is_active then
		fg = palette.tab_bar.active_tab.fg_color
		bg = palette.tab_bar.active_tab.bg_color
	end

	return {
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = utilities._space(title, options.padding.tabs.left, options.padding.tabs.right) },
	}
end)

wezterm.on("update-status", function(window, pane)
	local present, conf = pcall(window.effective_config, window)
	if not present then
		return
	end

	local palette = conf.resolved_palette

	-- left status
	local left_cells = {
		{ Background = { Color = palette.tab_bar.background } },
	}

	table.insert(left_cells, { Text = string.rep(" ", options.padding.left) })

	if options.modules.workspace.enabled then
		local stat = options.modules.workspace.icon
			.. utilities._space(window:active_workspace(), options.separator.space)
		local stat_fg = palette.ansi[options.modules.workspace.color]

		if options.modules.leader.enabled and window:leader_is_active() then
			stat_fg = palette.ansi[options.modules.leader.color]
			stat = utilities._constant_width(stat, options.modules.leader.icon)
		end

		table.insert(left_cells, { Foreground = { Color = stat_fg } })
		table.insert(left_cells, { Text = stat })
	end

	if options.modules.zoom.enabled and pane then
		local panes_with_info = pane:tab():panes_with_info()
		for _, p in ipairs(panes_with_info) do
			if p.is_active and p.is_zoomed then
				table.insert(left_cells, { Foreground = { Color = palette.ansi[options.modules.zoom.color] } })
				table.insert(
					left_cells,
					{ Text = options.modules.zoom.icon .. utilities._space("zoom", options.separator.space) }
				)
			end
		end
	end

	if options.modules.pane.enabled and pane then
		local process = pane:get_foreground_process_name()
		if not process then
			goto set_left_status
		end
		table.insert(left_cells, { Foreground = { Color = palette.ansi[options.modules.pane.color] } })
		table.insert(left_cells, {
			Text = options.modules.pane.icon .. utilities._space(utilities._basename(process), options.separator.space),
		})
	end

	::set_left_status::
	window:set_left_status(wezterm.format(left_cells))

	-- right status
	local right_cells = {
		{ Background = { Color = palette.tab_bar.background } },
	}

	local callbacks = {
		{
			name = "cwd",
			func = function()
				return paths.get_cwd(pane, true)
			end,
		},
		{
			name = "hostname",
			func = function()
				return wezterm.hostname()
			end,
		},
		{
			name = "username",
			func = function()
				return user.username
			end,
		},
		{
			name = "clock",
			func = function()
				return wezterm.time.now():format(options.modules.clock.format)
			end,
		},
	}

	for _, callback in ipairs(callbacks) do
		local name = callback.name
		local func = callback.func
		-- Get the module's configuration safely
		local mod_config = options.modules and options.modules[name]

		-- Check if the module is configured and enabled
		if mod_config and mod_config.enabled then
			local text = func()

			-- Also check if the function returned any text
			if text and #text > 0 then
				table.insert(right_cells, { Foreground = { Color = palette.ansi[mod_config.color] } })
				table.insert(right_cells, { Text = text })
				table.insert(right_cells, { Foreground = { Color = palette.brights[1] } })
				table.insert(right_cells, {
					Text = utilities._space(options.separator.right_icon, options.separator.space, nil)
						.. mod_config.icon,
				})
				table.insert(
					right_cells,
					{ Text = utilities._space(options.separator.field_icon, options.separator.space, nil) }
				)
			end
		end
	end
	-- remove trailing separator if items were added
	if #right_cells > 1 then
		table.remove(right_cells)
	end

	table.insert(right_cells, { Text = string.rep(" ", options.padding.right) })

	window:set_right_status(wezterm.format(right_cells))
end)

return M
