local wezterm = require("wezterm")
local config = wezterm.config_builder()
local mux = wezterm.mux
local act = wezterm.action

wezterm.on("gui-attached", function()
	for _, window in ipairs(mux.all_windows()) do
		local gui_window = window:gui_window()
		gui_window:maximize()
	end
end)

config:set_strict_mode(true)

config.launch_menu = {
	{
		label = "Windows PowerShell",
		domain = { DomainName = "local" },
		args = { "C:/Users/Miku/scoop/shims/pwsh.exe", "-NoLogo" },
	},
}
config.default_domain = "WSL:NixOS"

config.font = wezterm.font("R Maple Mono NF CN")
config.font_size = 11.5

config.initial_cols = 120
config.initial_rows = 30
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_background_opacity = 0.9
config.win32_system_backdrop = "Acrylic"
config.adjust_window_size_when_changing_font_size = false
config.audible_bell = "Disabled"
config.scrollback_lines = 10000
config.enable_kitty_graphics = true
config.max_fps = 240

config.keys = {
	{ key = " ", mods = "CTRL", action = act.SendKey({ key = " ", mods = "CTRL" }) },
	{ key = "LeftArrow", mods = "CTRL|ALT", action = act.ActivateTabRelative(-1) },
	{ key = "RightArrow", mods = "CTRL|ALT", action = act.ActivateTabRelative(1) },
	{ key = "LeftArrow", mods = "CTRL|SHIFT", action = act.MoveTabRelative(-1) },
	{ key = "RightArrow", mods = "CTRL|SHIFT", action = act.MoveTabRelative(1) },
	{ key = "[", mods = "CTRL|ALT", action = act.ActivateTabRelative(-1) },
	{ key = "]", mods = "CTRL|ALT", action = act.ActivateTabRelative(1) },
	{ key = "[", mods = "CTRL|SHIFT", action = act.MoveTabRelative(-1) },
	{ key = "]", mods = "CTRL|SHIFT", action = act.MoveTabRelative(1) },
	{ key = "n", mods = "CTRL|ALT", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "d", mods = "CTRL|ALT", action = act.CloseCurrentTab({ confirm = true }) },
}

local function clean_title(title)
	if not title or title == "" then
		return "WezTerm"
	end

	local normalized = title:gsub("\\", "/")
	local basename = normalized:match("^[A-Za-z]:/.+/([^/]+)$") or normalized:match("^//.+/([^/]+)$")
	if basename then
		return basename:gsub("%.[Ee][Xx][Ee]$", "")
	end

	return title
end

wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
	local pane = tab.active_pane
	local title = clean_title(pane and pane.title)
	if pane and pane.is_zoomed then
		title = "[Z] " .. title
	end

	return {
		{ Text = wezterm.truncate_right(title, max_width) },
	}
end)

return config
