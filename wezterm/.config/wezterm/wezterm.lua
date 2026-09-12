local wezterm = require("wezterm")
local config = wezterm.config_builder()

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
-- Defer a callback by one event-loop tick. Used by the auto-rebalance
-- handler so the mux has time to commit a pane removal before we read
-- tab:panes().
local function schedule(fn)
	wezterm.time.call_after(0.05, fn)
end

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
-- Master / stack tiling
--
-- Layout:
--   +-------------+----------------+
--   |             |    stack 1     |
--   |   master    +----------------+
--   |             |    stack 2     |
--   |             +----------------+
--   |             |    stack 3     |
--   +-------------+----------------+
--
-- IMPORTANT:
-- WezTerm's split sizes are relative to the pane being split, not
-- the whole column. To keep the stack equal, the stack panes are
-- built as a nested chain, and the new pane is always split off of
-- the CURRENT bottom-most stack pane (resolved from live geometry,
-- not insertion order), then equalize_stack() rebalances every
-- boundary in the column to the true 1/N split afterward:
--
--   2 panes: 50 / 50
--   3 panes: 33 / 33 / 33
--   4 panes: 25 / 25 / 25 / 25
------------------------------------------------------------
local tile_state = {}

local function get_tile_state(tab)
	local id = tab:tab_id()
	local state = tile_state[id]

	if not state then
		state = {
			master = nil,
			stack = {},
		}
		tile_state[id] = state
	end

	local live = {}
	for _, p in ipairs(tab:panes()) do
		live[p:pane_id()] = true
	end

	if state.master and not live[state.master] then
		state.master = nil
	end

	local stack = {}
	for _, pane_id in ipairs(state.stack) do
		if live[pane_id] and pane_id ~= state.master then
			stack[#stack + 1] = pane_id
		end
	end
	state.stack = stack

	return state
end

local function find_pane(tab, pane_id)
	if not pane_id then
		return nil
	end

	for _, p in ipairs(tab:panes()) do
		if p:pane_id() == pane_id then
			return p
		end
	end

	return nil
end

local function register_existing_layout(tab)
	local state = get_tile_state(tab)

	if state.master then
		return state
	end

	local panes = tab:panes_with_info()
	if #panes == 0 then
		return state
	end

	-- Existing layouts are assumed to have the left-most pane as
	-- master. Everything else is treated as the stack.
	table.sort(panes, function(a, b)
		if a.left == b.left then
			return a.top < b.top
		end
		return a.left < b.left
	end)

	state.master = panes[1].pane:pane_id()

	for i = 2, #panes do
		state.stack[#state.stack + 1] = panes[i].pane:pane_id()
	end

	return state
end

-- Resolves the bottom-most stack pane from actual geometry rather than
-- insertion order or a cached "anchor" id. This is what the new pane
-- always gets split off of, so the stack grows as a flat run of
-- siblings-by-position instead of nesting deeper inside one shrinking
-- pane every time.
local function bottom_stack_pane(tab, state)
	local infos = tab:panes_with_info()
	local by_id = {}
	for _, info in ipairs(infos) do
		by_id[info.pane:pane_id()] = info
	end

	local stack_infos = {}
	for _, pane_id in ipairs(state.stack) do
		local info = by_id[pane_id]
		if info then
			stack_infos[#stack_infos + 1] = info
		end
	end

	if #stack_infos == 0 then
		return nil
	end

	table.sort(stack_infos, function(a, b)
		return a.top < b.top
	end)

	return stack_infos[#stack_infos].pane
end

local function equalize_stack(window, tab, state)
	if #state.stack < 2 then
		return
	end

	-- IMPORTANT: AdjustPaneSize always resizes whichever pane is
	-- currently ACTIVE in the GUI -- the `pane` argument passed to
	-- window:perform_action() is documented upstream to have no
	-- effect on which pane actually gets resized (see wezterm issue
	-- #4038: "adjustPaneSize only acts on the active pane even in
	-- the scope of perform_action"). So every target pane must be
	-- explicitly activated immediately before its AdjustPaneSize
	-- call, or the resize silently lands on whatever pane happened
	-- to be focused instead. We restore the original focus once
	-- equalization is done.
	local original_active = tab:active_pane()

	-- Normalize the stack using the actual pane geometry.  WezTerm's
	-- AdjustPaneSize changes the boundary adjacent to the active pane,
	-- so we adjust each boundary independently from top to bottom.
	-- A tiny yield after each change lets the mux update its geometry
	-- before we measure the next boundary.
	for pass = 1, 4 do
		local infos = tab:panes_with_info()
		local by_id = {}

		for _, info in ipairs(infos) do
			by_id[info.pane:pane_id()] = info
		end

		local stack_infos = {}
		for _, pane_id in ipairs(state.stack) do
			local info = by_id[pane_id]
			if info then
				stack_infos[#stack_infos + 1] = info
			end
		end

		table.sort(stack_infos, function(a, b)
			return a.top < b.top
		end)

		if #stack_infos < 2 then
			break
		end

		local first = stack_infos[1]
		local last = stack_infos[#stack_infos]
		local top = first.top
		local bottom = last.top + last.height
		local total = bottom - top
		local count = #stack_infos
		local changed = false

		for i = 1, count - 1 do
			-- The boundary below stack pane i should be exactly this far
			-- down from the top of the stack column.
			local desired = top + math.floor(total * i / count + 0.5)
			local info = stack_infos[i]
			local current = info.top + info.height
			local delta = desired - current

			if math.abs(delta) >= 1 then
				info.pane:activate()
				window:perform_action(
					wezterm.action.AdjustPaneSize({
						delta > 0 and "Down" or "Up",
						math.abs(delta),
					}),
					info.pane
				)

				changed = true
				wezterm.sleep_ms(5)
			end
		end

		if not changed then
			break
		end
	end

	if original_active then
		original_active:activate()
	end
end

------------------------------------------------------------
-- Auto-rebalance stack when a pane closes (polling approach)
------------------------------------------------------------
-- WezTerm has no pane-close event, and pane-focus-changed fires
-- *before* the mux removes the dead pane from tab:panes(), so it
-- cannot reliably detect a close. Instead we poll the pane count
-- on every status update. This is cheap because we early-out as
-- soon as the count matches what we expect.
local _last_pane_count = {}

wezterm.on("update-status", function(window, pane)
	local tab = pane:tab()
	if not tab then
		return
	end

	local tab_id = tab:tab_id()
	local state = tile_state[tab_id]
	if not state then
		return
	end

	local expected = (state.master and 1 or 0) + #state.stack
	local actual = #tab:panes()

	-- Fast path: count matches, nothing has closed.
	if actual >= expected then
		_last_pane_count[tab_id] = actual
		return
	end

	-- Count dropped. Guard against firing multiple times for the
	-- same close by checking we haven't already processed this count.
	if _last_pane_count[tab_id] == actual then
		return
	end
	_last_pane_count[tab_id] = actual

	-- Rebuild the live set and rebalance.
	local live = {}
	for _, p in ipairs(tab:panes()) do
		live[p:pane_id()] = true
	end

	local master_alive = state.master and live[state.master]

	local new_stack = {}
	local stack_changed = false
	for _, pid in ipairs(state.stack) do
		if live[pid] then
			new_stack[#new_stack + 1] = pid
		else
			stack_changed = true
		end
	end

	if not master_alive then
		-- Master died; drop cache and let next tiling action re-derive.
		tile_state[tab_id] = nil
		return
	end

	if not stack_changed then
		return
	end

	state.stack = new_stack

	if #state.stack >= 2 then
		equalize_stack(window, tab, state)
	end
end)

local function spawn_tile(window, pane)
	local tab = pane:tab()
	if not tab then
		return
	end

	local state = register_existing_layout(tab)

	if not state.master then
		state.master = pane:pane_id()
		return
	end

	-- First stack pane: create the master column and stack column.
	if #state.stack == 0 then
		local new_pane = pane:split({
			direction = "Right",
			size = 0.5,
			top_level = true,
		})

		state.stack[#state.stack + 1] = new_pane:pane_id()
		new_pane:activate()
		return
	end

	-- Always split the CURRENT bottom-most stack pane (resolved from
	-- actual geometry), then immediately rebalance ALL stack panes.
	-- The split's initial size is just a reasonable starting point --
	-- it doesn't need to be exact, since equalize_stack() below
	-- corrects every boundary to the true 1/N split afterward.
	local new_count = #state.stack + 1
	local anchor = bottom_stack_pane(tab, state)
	if not anchor then
		return
	end

	local new_pane = anchor:split({
		direction = "Bottom",
		size = 1 / new_count,
	})

	state.stack[#state.stack + 1] = new_pane:pane_id()

	-- Give the mux a moment to commit the new split before measuring it.
	wezterm.sleep_ms(10)
	equalize_stack(window, tab, state)
	new_pane:activate()
end

-- Swap the focused stack pane with the master.
-- WezTerm provides PaneSelect for this exact operation, so the
-- focused pane can be swapped with whichever pane is selected.
local function swap_master_stack(window, pane)
	local tab = pane:tab()
	if not tab then
		return
	end

	local state = register_existing_layout(tab)
	if not state.master or #state.stack == 0 then
		return
	end

	window:perform_action(
		wezterm.action.PaneSelect({
			mode = "SwapWithActiveKeepFocus",
			show_pane_ids = true,
		}),
		pane
	)

	-- PaneSelect performs the swap itself, asynchronously, once the user
	-- picks a target -- it has no completion callback we can hook. The
	-- swap exchanges the two panes' on-screen positions but not their
	-- pane IDs, so our cached state.master/state.stack (which track
	-- roles by ID) would go stale immediately: state.master would still
	-- point at a pane that's no longer positioned as master.
	--
	-- Rather than guess at the outcome, drop the cached layout for this
	-- tab entirely. The next tiling operation (spawn_tile, another swap,
	-- focus_master_stack) will call register_existing_layout, see no
	-- cached master, and re-derive master/stack from actual pane
	-- geometry -- which by then reflects the completed swap.
	tile_state[tab:tab_id()] = nil
end

-- Master -> first stack pane.
-- Any stack pane -> master.
local function focus_master_stack(window, pane)
	local tab = pane:tab()
	if not tab then
		return
	end

	local state = register_existing_layout(tab)
	local master = find_pane(tab, state.master)

	if not master then
		return
	end

	if pane:pane_id() == master:pane_id() then
		local first_stack = find_pane(tab, state.stack[1])
		if first_stack then
			first_stack:activate()
		end
	else
		master:activate()
	end
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
	-- Master / stack tiling
	----------------------------------------------------------
	-- Spawn the next tile in the master/stack layout.
	{ key = "Enter", mods = "LEADER", action = wezterm.action_callback(spawn_tile) },
	-- Focused stack tile becomes master; old master becomes stack.
	{ key = "m", mods = "LEADER", action = wezterm.action_callback(swap_master_stack) },
	-- Master <-> first stack tile.
	{ key = "Tab", mods = "LEADER", action = wezterm.action_callback(focus_master_stack) },

	----------------------------------------------------------
	-- Pane close
	----------------------------------------------------------
	{ key = "q", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = false }) },

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
