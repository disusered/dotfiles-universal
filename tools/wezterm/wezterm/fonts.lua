local wezterm = require("wezterm")

-- This is the module table that we will export
local module = {}

-- The suggested convention for making modules that update
-- the config is for them to export an `apply_to_config`
-- function that accepts the config object, like this:
function module.apply_to_config(config)
	-- Set the font to use
	config.font = wezterm.font("JetBrains Mono", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- <built-in>, BuiltIn
	-- config.font = wezterm.font("Noto Color Emoji", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- <built-in>, BuiltIn
	-- config.font = wezterm.font("Roboto", { weight = "Regular", stretch = "Normal", style = "Italic" }) -- <built-in>, BuiltIn
	-- config.font = wezterm.font("Cascadia Code", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- C:\PROGRAM FILES\WINDOWSAPPS\MICROSOFT.WINDOWSTERMINAL_1.22.11141.0_X64__8WEKYB3D8BBWE\CASCADIACODE.TTF index=0 variation=4, DirectWrite
	-- config.font =
	-- 	wezterm.font("CaskaydiaCove Nerd Font Mono", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- (AKA: CaskaydiaCove NFM) C:\USERS\CARLO\APPDATA\LOCAL\MICROSOFT\WINDOWS\FONTS\CASKAYDIACOVENERDFONTMONO-REGULAR.TTF, DirectWrite
	-- config.font = wezterm.font("Consolas", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- C:\WINDOWS\FONTS\CONSOLAB.TTF, DirectWrite
	-- config.font = wezterm.font("Fira Code", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- C:\USERS\CARLO\APPDATA\LOCAL\MICROSOFT\WINDOWS\FONTS\FIRACODE-REGULAR.TTF, DirectWrite
	-- config.font = wezterm.font("Hack", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- C:\WINDOWS\FONTS\HACK-REGULAR.TTF, DirectWrite
	-- config.font = wezterm.font("Hasklig", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- C:\USERS\CARLO\APPDATA\LOCAL\MICROSOFT\WINDOWS\FONTS\HASKLIG-REGULAR.OTF, DirectWrite
	-- config.font = wezterm.font("Ubuntu Mono", { weight = "Regular", stretch = "Normal", style = "Normal" }) -- C:\USERS\CARLO\APPDATA\LOCAL\MICROSOFT\WINDOWS\FONTS\UBUNTUMONO[WGHT].TTF index=0 variation=1, DirectWrite

	-- Font size
	config.font_size = 9
end

-- return our module table
return module
