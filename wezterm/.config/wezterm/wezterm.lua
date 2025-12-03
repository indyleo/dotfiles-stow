local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Read theme from cache file
local function read_theme()
	local handle = io.open(os.getenv("HOME") .. "/.cache/theme", "r")
	if handle then
		local theme = handle:read("*a"):gsub("%s+", "") -- trim whitespace
		handle:close()
		return theme
	end
	return "gruvbox" -- default
end

-- Gruvbox Dark color scheme
local gruvbox = {
	foreground = "#ebdbb2",
	background = "#282828",
	cursor_bg = "#ebdbb2",
	cursor_fg = "#282828",
	cursor_border = "#ebdbb2",
	selection_fg = "#282828",
	selection_bg = "#ebdbb2",
	ansi = {
		"#282828", -- black
		"#cc241d", -- red
		"#98971a", -- green
		"#d79921", -- yellow
		"#458588", -- blue
		"#b16286", -- magenta
		"#689d6a", -- cyan
		"#a89984", -- white
	},
	brights = {
		"#928374", -- bright black
		"#fb4934", -- bright red
		"#b8bb26", -- bright green
		"#fabd2f", -- bright yellow
		"#83a598", -- bright blue
		"#d3869b", -- bright magenta
		"#8ec07c", -- bright cyan
		"#ebdbb2", -- bright white
	},
}

-- Nord color scheme
local nord = {
	foreground = "#d8dee9",
	background = "#2e3440",
	cursor_bg = "#d8dee9",
	cursor_fg = "#2e3440",
	cursor_border = "#d8dee9",
	selection_fg = "#d8dee9",
	selection_bg = "#434c5e",
	ansi = {
		"#3b4252", -- black
		"#bf616a", -- red
		"#a3be8c", -- green
		"#ebcb8b", -- yellow
		"#81a1c1", -- blue
		"#b48ead", -- magenta
		"#88c0d0", -- cyan
		"#e5e9f0", -- white
	},
	brights = {
		"#4c566a", -- bright black
		"#bf616a", -- bright red
		"#a3be8c", -- bright green
		"#ebcb8b", -- bright yellow
		"#81a1c1", -- bright blue
		"#b48ead", -- bright magenta
		"#8fbcbb", -- bright cyan
		"#eceff4", -- bright white
	},
}

-- Select theme based on cache file
local theme_name = read_theme()
local colors = gruvbox -- default
if theme_name == "nord" then
	colors = nord
end

-- Apply colors to config
config.colors = colors

-- Watch the theme file for changes and reload automatically
wezterm.add_to_config_reload_watch_list(os.getenv("HOME") .. "/.cache/theme")

-- Font and appearance
config.font = wezterm.font("CaskaydiaCove NF")
config.font_size = 12.0
config.enable_tab_bar = true
config.window_padding = {
	left = 6,
	right = 6,
	top = 6,
	bottom = 6,
}
config.window_background_opacity = 0.85
config.enable_scroll_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true

-- Automatically reload on window focus (helps with hot reloading)
config.automatically_reload_config = true

return config
