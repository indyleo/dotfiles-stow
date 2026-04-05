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
config.visual_bell = { fade_in_duration_ms = 0, fade_out_duration_ms = 0 }
config.front_end = "WebGpu"
config.automatically_reload_config = true

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

local excluded_dirs = {
	bin = 1,
	lib = 1,
	include = 1,
	utils = 1,
	example = 1,
	examples = 1,
	node_modules = 1,
	vendor = 1,
	dist = 1,
	build = 1,
	["zig-out"] = 1,
	cmd = 1,
	demo = 1,
	scripts = 1,
	test = 1,
	tests = 1,
	schema = 1,
	pkg = 1,
	docs = 1,
	src = 1,
	res = 1,
}

local function basename(path)
	return path:match("([^/]+)$") or path
end

local function safe_name(name)
	return name:gsub("[%.%s]", "_")
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

local function find_projects()
	local results, seen = {}, {}
	for _, root in ipairs(search_dirs) do
		for _, dir in ipairs(shell_lines("find " .. root .. " -mindepth 1 -maxdepth 2 -type d -not -path '*/.*'")) do
			local bname = basename(dir)
			if not excluded_dirs[bname] and not seen[dir] then
				seen[dir] = true
				results[#results + 1] = dir
			end
		end
	end
	return results
end

local function find_git_repos()
	local results, seen = {}, {}
	for _, root in ipairs(search_dirs) do
		for _, git_dir in ipairs(shell_lines("find " .. root .. " -mindepth 2 -maxdepth 3 -type d -name .git")) do
			local repo = git_dir:match("^(.+)/%.git$")
			if repo and not seen[repo] then
				seen[repo] = true
				results[#results + 1] = repo
			end
		end
	end
	table.sort(results)
	return results
end

local function open_project(window, pane, project_path)
	local name = safe_name(basename(project_path))

	-- Switch to the workspace if it already exists
	for _, ws in ipairs(wezterm.mux.get_workspace_names()) do
		if ws == name then
			window:perform_action(wezterm.action.SwitchToWorkspace({ name = name }), pane)
			return
		end
	end

	-- Create a new window in the background assigned to our new workspace
	-- This returns the newly created tab, pane, and window objects synchronously
	local nvim_tab, nvim_pane, mux_window = wezterm.mux.spawn_window({
		workspace = name,
		cwd = project_path,
		args = { "nvim", "-c", ":Lf" },
	})

	-- Spawn the second tab (the plain shell) inside that same new window
	mux_window:spawn_tab({ cwd = project_path })

	-- Make sure the first tab (Neovim) is the one in focus
	nvim_tab:activate()

	-- Finally, switch your GUI to the fully constructed workspace
	window:perform_action(
		wezterm.action.SwitchToWorkspace({
			name = name,
		}),
		pane
	)
end

local function paths_to_choices(paths)
	local choices = {}
	for _, p in ipairs(paths) do
		choices[#choices + 1] = { label = p, id = p }
	end
	return choices
end

local function pick_action(mode)
	return wezterm.action_callback(function(window, pane)
		local paths = mode == "git" and find_git_repos() or find_projects()

		if #paths == 0 then
			window:toast_notification("project-session", "No projects found.", nil, 4000)
			return
		end

		window:perform_action(
			wezterm.action.InputSelector({
				action = wezterm.action_callback(function(win, pn, id)
					if id then
						open_project(win, pn, id)
					end
				end),
				title = mode == "git" and "Git repos" or "Projects",
				choices = paths_to_choices(paths),
				fuzzy = true,
				fuzzy_description = "Search: ",
			}),
			pane
		)
	end)
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
	{ key = "p", mods = "LEADER", action = pick_action("project") },
	{ key = "g", mods = "LEADER", action = pick_action("git") },
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
