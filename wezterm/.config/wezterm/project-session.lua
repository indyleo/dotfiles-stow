-- project-session.lua
-- Drop-in replacement for tmux-project-session.sh, but native WezTerm.
-- Source this file from your wezterm.lua:
--
--   local ps = require("project-session")
--   ps.apply(config)   -- registers keybinds onto your config table
--
-- Then press:
--   CTRL+SHIFT+P  → pick any project folder (all subdirs)
--   CTRL+SHIFT+G  → pick only git repos

local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- ── Configuration ────────────────────────────────────────────────────────────

M.search_dirs = {
	wezterm.home_dir .. "/Projects",
	wezterm.home_dir .. "/Github",
}

-- Directories to skip when collecting project roots
M.excluded_dirs = {
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

-- Key bindings (override before calling apply() if you want different keys)
M.key_project = { key = "p", mods = "CTRL|SHIFT" }
M.key_git = { key = "g", mods = "CTRL|SHIFT" }

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Run a shell command, return its stdout lines as a table.
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

-- Return the basename of a path.
local function basename(path)
	return path:match("([^/]+)$") or path
end

-- Replace characters that are invalid in a WezTerm workspace title.
local function safe_name(name)
	return name:gsub("[%.%s]", "_")
end

-- ── Project discovery ─────────────────────────────────────────────────────────

-- Collect all directories up to depth 2 under each search root,
-- skipping hidden paths and the excluded_dirs list.
local function find_projects(search_dirs)
	local results = {}
	local seen = {}

	for _, root in ipairs(search_dirs) do
		local attr = wezterm.read_dir and nil -- just existence check below
		local lines = shell_lines("find " .. root .. " -mindepth 1 -maxdepth 2 -type d -not -path '*/.*'")
		for _, dir in ipairs(lines) do
			local bname = basename(dir)
			if not M.excluded_dirs[bname] and not seen[dir] then
				seen[dir] = true
				results[#results + 1] = dir
			end
		end
	end

	return results
end

-- Collect only directories that contain a .git folder (depth 1-3).
local function find_git_repos(search_dirs)
	local results = {}
	local seen = {}

	for _, root in ipairs(search_dirs) do
		local lines = shell_lines("find " .. root .. " -mindepth 2 -maxdepth 3 -type d -name .git")
		for _, git_dir in ipairs(lines) do
			-- parent of .git is the repo root
			local repo = git_dir:match("^(.+)/%.git$")
			if repo and not seen[repo] then
				seen[repo] = true
				results[#results + 1] = repo
			end
		end
	end

	-- sort for stable ordering
	table.sort(results)
	return results
end

-- ── Session creation ──────────────────────────────────────────────────────────

-- Build the InputSelector choices list from a list of paths.
local function paths_to_choices(paths)
	local choices = {}
	for _, path in ipairs(paths) do
		choices[#choices + 1] = {
			label = path,
			id = path,
		}
	end
	return choices
end

-- Called when the user picks a project from the fuzzy finder.
-- Creates (or switches to) a workspace for that project.
-- Window layout: left pane = nvim, right pane = shell.
local function open_project(window, pane, project_path)
	local name = safe_name(basename(project_path))

	-- Switch to the workspace if it already exists.
	for _, ws in ipairs(wezterm.mux.get_workspace_names()) do
		if ws == name then
			window:perform_action(act.SwitchToWorkspace({ name = name }), pane)
			return
		end
	end

	-- Create a fresh workspace, spawning the first tab in the project dir.
	window:perform_action(
		act.SwitchToWorkspace({
			name = name,
			spawn = {
				label = name,
				cwd = project_path,
			},
		}),
		pane
	)

	-- Give WezTerm a tick to set up the new tab before we split it.
	wezterm.time.call_after(0.05, function()
		-- Grab the active pane in the freshly-created workspace.
		local mux_window = wezterm.mux.get_active_window()
		if not mux_window then
			return
		end

		local tab = mux_window:active_tab()
		local nvim = tab:active_pane()

		-- Launch nvim in the left (initial) pane.
		nvim:send_text("nvim\n")

		-- Split right → shell pane.
		local shell_pane = tab:active_pane():split({
			direction = "Right",
			size = 0.40, -- shell gets 40 % of the width
			cwd = project_path,
		})

		-- Keep focus on the nvim pane.
		nvim:activate()
		_ = shell_pane -- suppress unused-variable warning
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Build and return an InputSelector action for the given mode.
-- mode: "project" | "git"
function M.pick_action(mode)
	return wezterm.action_callback(function(window, pane)
		local paths

		if mode == "git" then
			paths = find_git_repos(M.search_dirs)
		else
			paths = find_projects(M.search_dirs)
		end

		if #paths == 0 then
			window:toast_notification(
				"project-session",
				"No projects found in configured search directories.",
				nil,
				4000
			)
			return
		end

		window:perform_action(
			act.InputSelector({
				action = wezterm.action_callback(function(win, pn, id, _label)
					if id then
						open_project(win, pn, id)
					end
				end),
				title = mode == "git" and "Git repos" or "Projects",
				choices = paths_to_choices(paths),
				fuzzy = true,
				fuzzy_description = "Search: ",
				description = mode == "git" and "Select a git repository to open" or "Select a project to open",
			}),
			pane
		)
	end)
end

-- Register keybinds onto an existing config table.
-- Call this inside your wezterm.lua:
--
--   local ps = require("project-session")
--   ps.apply(config)
function M.apply(config)
	config.keys = config.keys or {}

	table.insert(config.keys, {
		key = M.key_project.key,
		mods = M.key_project.mods,
		action = M.pick_action("project"),
	})

	table.insert(config.keys, {
		key = M.key_git.key,
		mods = M.key_git.mods,
		action = M.pick_action("git"),
	})
end

return M
