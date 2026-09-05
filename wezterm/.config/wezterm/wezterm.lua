local wezterm = require("wezterm")
local config = wezterm.config_builder()

------------------------------------------------------------
-- Color Schemes
------------------------------------------------------------
local gruvbox = {
	background = "#282828",
	foreground = "#ebdbb2",

	cursor_bg = "#fabd2f",
	cursor_fg = "#282828",
	cursor_border = "#fabd2f",

	selection_fg = "#282828",
	selection_bg = "#83a598",

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
config.colors = gruvbox

------------------------------------------------------------
-- Terminal identity + shell
------------------------------------------------------------
config.term = "xterm-256color"
config.default_prog = { "zsh" }
config.enable_wayland = false

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
config.automatically_reload_config = true

------------------------------------------------------------
-- Performance
------------------------------------------------------------
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.max_fps = 60
config.scrollback_lines = 10000
config.mux_output_parser_buffer_size = 1048576
config.mux_output_parser_coalesce_delay_ms = 1
-- NOTE: prefer_egl only has an effect when front_end = "OpenGL" - it's a
-- no-op with WebGpu (current setting). Left in place in case you ever
-- switch front ends back, but it isn't doing anything right now.
config.prefer_egl = false
config.window_close_confirmation = "NeverPrompt"

------------------------------------------------------------
-- Mouse bindings
------------------------------------------------------------
config.mouse_bindings = {
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

------------------------------------------------------------
-- Project session
------------------------------------------------------------
local home = wezterm.home_dir

local search_dirs = {
	home .. "/Projects",
	home .. "/Github",
}

local function basename(path)
	return path:match("([^/]+)$") or path
end

local function safe_name(name)
	return (name:gsub("[%.%s]", "_"))
end

-- Single-quotes a string for safe interpolation into a POSIX shell command
-- line. Without this, a search_dirs entry containing a space or other shell
-- metacharacter would break (or silently misbehave) the `find` invocation
-- below.
local function shell_quote(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function shell_lines(cmd)
	local handle = io.popen(cmd .. " 2>/dev/null")
	if not handle then
		return {}
	end
	local lines = {}
	for line in handle:lines() do
		lines[#lines + 1] = line
	end
	handle:close()
	return lines
end

-- Cache: populated on first picker open, persists for the session.
-- Force a fresh scan with LEADER+SHIFT+P if you add a new project directory
-- and don't want to wait for a config reload.
local _cache = {}

local function scan_dirs()
	if _cache.scanned then
		return
	end
	local git_repos = {}
	local seen = {}

	for _, root in ipairs(search_dirs) do
		local cmd = "find " .. shell_quote(root) .. " -mindepth 2 -maxdepth 4 -type d -name '.git'"
		for _, p in ipairs(shell_lines(cmd)) do
			local repo = p:match("^(.+)/%.git$")
			if repo and not seen[repo] then
				seen[repo] = true
				git_repos[#git_repos + 1] = repo
			end
		end
	end

	table.sort(git_repos)

	-- Build workspace names. Two repos with the same basename (e.g.
	-- ~/Projects/foo and ~/Github/foo) would otherwise collide and
	-- open_project() would treat the second one as "already open" and
	-- just switch to the first repo's workspace instead of opening it.
	-- Disambiguate by prefixing the parent directory name only when a
	-- collision actually exists, so names stay short in the common case.
	local basename_counts = {}
	for _, repo in ipairs(git_repos) do
		local b = basename(repo)
		basename_counts[b] = (basename_counts[b] or 0) + 1
	end

	local names = {}
	for _, repo in ipairs(git_repos) do
		local b = basename(repo)
		if basename_counts[b] > 1 then
			local parent = basename(repo:match("^(.+)/[^/]+$") or repo)
			names[repo] = safe_name(parent .. "_" .. b)
		else
			names[repo] = safe_name(b)
		end
	end

	_cache.git_repos = git_repos
	_cache.names = names
	_cache.scanned = true
end

local function open_project(window, pane, project_path)
	local name = (_cache.names and _cache.names[project_path]) or safe_name(basename(project_path))

	for _, ws in ipairs(wezterm.mux.get_workspace_names()) do
		if ws == name then
			window:perform_action(wezterm.action.SwitchToWorkspace({ name = name }), pane)
			return
		end
	end

	local nvim_tab, _, mux_window = wezterm.mux.spawn_window({
		workspace = name,
		cwd = project_path,
		args = { "nvim", "-c", ":Lf" },
	})

	mux_window:spawn_tab({ cwd = project_path })
	nvim_tab:activate()

	window:perform_action(wezterm.action.SwitchToWorkspace({ name = name }), pane)
end

local function pick_projects(window, pane)
	scan_dirs()
	local paths = _cache.git_repos

	if #paths == 0 then
		window:toast_notification("project-session", "No projects found.", nil, 4000)
		return
	end

	local choices = {}
	for _, p in ipairs(paths) do
		choices[#choices + 1] = { label = p, id = p }
	end

	window:perform_action(
		wezterm.action.InputSelector({
			action = wezterm.action_callback(function(win, pn, id)
				if id then
					open_project(win, pn, id)
				end
			end),
			title = "Projects",
			choices = choices,
			fuzzy = true,
			fuzzy_description = "Search: ",
		}),
		pane
	)
end

local function refresh_projects(window, pane)
	_cache.scanned = false
	pick_projects(window, pane)
end

------------------------------------------------------------
-- Leader and keybindings
------------------------------------------------------------
config.leader = { key = "Space", mods = "CTRL" }

config.keys = {
	----------------------------------------------------------
	-- Pane navigation (vim-style)
	----------------------------------------------------------
	{ key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },

	----------------------------------------------------------
	-- Splits
	----------------------------------------------------------
	{ key = "-", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "\\", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },

	----------------------------------------------------------
	-- Pane close
	----------------------------------------------------------
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },

	----------------------------------------------------------
	-- Tabs
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
	-- Workspace / project picker
	----------------------------------------------------------
	{ key = "p", mods = "LEADER", action = wezterm.action_callback(pick_projects) },
	{ key = "P", mods = "LEADER|SHIFT", action = wezterm.action_callback(refresh_projects) },
	{
		key = "w",
		mods = "LEADER",
		action = wezterm.action.ShowLauncherArgs({ flags = "WORKSPACES" }),
	},

	----------------------------------------------------------
	-- Clear screen
	----------------------------------------------------------
	{ key = "l", mods = "CTRL", action = wezterm.action.SendString("\x0c") },

	----------------------------------------------------------
	-- Copy & paste
	----------------------------------------------------------
	{ key = "C", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("ClipboardAndPrimarySelection") },
	{ key = "V", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },

	----------------------------------------------------------
	-- Search
	----------------------------------------------------------
	{ key = "F", mods = "CTRL|SHIFT", action = wezterm.action.Search({ CaseSensitiveString = "" }) },

	----------------------------------------------------------
	-- Copy mode (vim normal mode)
	----------------------------------------------------------
	{ key = "Space", mods = "CTRL|ALT", action = wezterm.action.ActivateCopyMode },
	{
		key = "Escape",
		mods = "CTRL",
		action = wezterm.action.Multiple({ wezterm.action.CopyMode("Close") }),
	},
}

return config
