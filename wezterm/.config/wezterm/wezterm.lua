local wezterm = require("wezterm")
local config = wezterm.config_builder()

------------------------------------------------------------
-- Read theme from file
------------------------------------------------------------
local function read_theme()
	local handle = io.open(os.getenv("HOME") .. "/.cache/theme", "r")
	if handle then
		local theme = handle:read("*a"):gsub("%s+", "")
		handle:close()
		return theme
	end
	return "gruvbox"
end

------------------------------------------------------------
-- Color Schemes
------------------------------------------------------------
local gruvbox = {
	foreground = "#ebdbb2",
	background = "#282828",
	cursor_bg = "#ebdbb2",
	cursor_fg = "#282828",
	cursor_border = "#ebdbb2",
	selection_fg = "#282828",
	selection_bg = "#ebdbb2",
	ansi = {
		"#282828",
		"#cc241d",
		"#98971a",
		"#d79921",
		"#458588",
		"#b16286",
		"#689d6a",
		"#a89984",
	},
	brights = {
		"#928374",
		"#fb4934",
		"#b8bb26",
		"#fabd2f",
		"#83a598",
		"#d3869b",
		"#8ec07c",
		"#ebdbb2",
	},
}

local nord = {
	foreground = "#d8dee9",
	background = "#2e3440",
	cursor_bg = "#d8dee9",
	cursor_fg = "#2e3440",
	cursor_border = "#d8dee9",
	selection_fg = "#d8dee9",
	selection_bg = "#434c5e",
	ansi = {
		"#3b4252",
		"#bf616a",
		"#a3be8c",
		"#ebcb8b",
		"#81a1c1",
		"#b48ead",
		"#88c0d0",
		"#e5e9f0",
	},
	brights = {
		"#4c566a",
		"#bf616a",
		"#a3be8c",
		"#ebcb8b",
		"#81a1c1",
		"#b48ead",
		"#8fbcbb",
		"#eceff4",
	},
}

local theme_name = read_theme()
local colors = theme_name == "nord" and nord or gruvbox
config.colors = colors

wezterm.add_to_config_reload_watch_list(os.getenv("HOME") .. "/.cache/theme")

------------------------------------------------------------
-- Terminal identity + shell
------------------------------------------------------------
config.term = "xterm-256color" -- matches Alacritty/st
config.default_prog = { "zsh" } -- matches tmux/Alacritty/st

------------------------------------------------------------
-- Appearance
------------------------------------------------------------
config.font = wezterm.font("CaskaydiaCove NF")
config.font_size = 12.0
config.window_padding = { left = 6, right = 6, top = 6, bottom = 6 }
config.window_background_opacity = 0.85
config.enable_scroll_bar = false
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_duration_ms = 0,
	fade_out_duration_ms = 0,
}

config.mouse_bindings = {
	-- Right-click paste (Alacritty style)
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = wezterm.action.PasteFrom("Clipboard"),
	},
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "CTRL",
		action = wezterm.action.OpenLinkAtMouseCursor,
	},
}

config.automatically_reload_config = true

------------------------------------------------------------
-- Leader (tmux prefix) and keybindings
------------------------------------------------------------
config.leader = { key = "Space", mods = "CTRL" } -- same as tmux: C-Space

config.keys = {
	----------------------------------------------------------
	-- tmux-like pane navigation
	----------------------------------------------------------
	{ key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },

	----------------------------------------------------------
	-- tmux-like splits
	----------------------------------------------------------
	{ key = "-", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "\\", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },

	----------------------------------------------------------
	-- Close pane
	----------------------------------------------------------
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },

	----------------------------------------------------------
	-- New tab, tab switching (Alacritty + tmux similarities)
	----------------------------------------------------------
	{ key = "c", mods = "LEADER", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "1", mods = "ALT", action = wezterm.action.ActivateTab(0) },
	{ key = "2", mods = "ALT", action = wezterm.action.ActivateTab(1) },
	{ key = "3", mods = "ALT", action = wezterm.action.ActivateTab(2) },
	{ key = "4", mods = "ALT", action = wezterm.action.ActivateTab(3) },
	{ key = "5", mods = "ALT", action = wezterm.action.ActivateTab(4) },
	{ key = "6", mods = "ALT", action = wezterm.action.ActivateTab(5) },
	{ key = "7", mods = "ALT", action = wezterm.action.ActivateTab(6) },
	{ key = "8", mods = "ALT", action = wezterm.action.ActivateTab(7) },
	{ key = "9", mods = "ALT", action = wezterm.action.ActivateTab(8) },

	----------------------------------------------------------
	-- Clear screen (Ctrl+L behavior from Alacritty)
	----------------------------------------------------------
	{
		key = "l",
		mods = "CTRL",
		action = wezterm.action.SendString("\x0c"), -- ^L
	},

	----------------------------------------------------------
	-- Copy & paste behavior similar to Alacritty
	----------------------------------------------------------
	{
		key = "C",
		mods = "CTRL|SHIFT",
		action = wezterm.action.CopyTo("ClipboardAndPrimarySelection"),
	},
	{
		key = "V",
		mods = "CTRL|SHIFT",
		action = wezterm.action.PasteFrom("Clipboard"),
	},

	----------------------------------------------------------
	-- Search (similar to Alacritty)
	----------------------------------------------------------
	{
		key = "F",
		mods = "CTRL|SHIFT",
		action = wezterm.action.Search({ CaseSensitiveString = "" }),
	},

	----------------------------------------------------------
	-- Vim-like Normal Mode (Copy Mode)
	----------------------------------------------------------
	-- Enter Normal/Copy Mode with CTRL-Space
	{ key = "Space", mods = "CTRL|ALT", action = wezterm.action.ActivateCopyMode },

	-- Leave Copy Mode with Escape
	{
		key = "Escape",
		mods = "CTRL",
		action = wezterm.action.Multiple({
			wezterm.action.CopyMode("Close"),
		}),
	},
}

return config
