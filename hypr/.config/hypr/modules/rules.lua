-- ################################################################## --
-- __        ___           _                 ____        _            --
-- \ \      / (_)_ __   __| | _____      __ |  _ \ _   _| | ___  ___  --
--  \ \ /\ / /| | '_ \ / _` |/ _ \ \ /\ / / | |_) | | | | |/ _ \/ __| --
--   \ V  V / | | | | | (_| | (_) \ V  V /  |  _ <| |_| | |  __/\__ \ --
--    \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/   |_| \_\\__,_|_|\___||___/ --
-- ################################################################## --

-- ========================= MONITORS ================================ --

local MON_TOP = "HDMI-A-1" -- monitor 0: workspaces 1-5
local MON_MAIN = "DP-1" -- monitor 1: workspaces 6-10
local MON_TOUCH = "HDMI-A-4" -- monitor 2: workspaces 11-15

-- ========================= WORKSPACE MAP =========================== --
-- hyprsplit gives each monitor 5 workspaces (num_workspaces = 5), so the
-- rules below use global workspace IDs:
--
--   1   btop                     (top monitor)
--   6   LibreWolf                (main monitor)
--   7   Vesktop / Discord        (main monitor)
--   8   Terminal, indy terminal  (main monitor)
--   9   Steam client             (main monitor)
--   11  Feishin                  (touch monitor)

-- ========================= HELPERS ================================= --

-- Build a workspace rule string from a global workspace ID and a monitor.
-- Under hyprsplit, IDs 1-5 / 6-10 / 11-15 belong to monitors 0 / 1 / 2.
local function ws(number, monitor)
	return string.format("%d monitor:%s", number, monitor)
end

-- Open windows of a class on a fixed workspace and monitor, every time
-- they are launched (not just at startup).
local function place(name, class, workspace, monitor)
	hl.window_rule({
		name = name,
		match = { class = class },
		workspace = ws(workspace, monitor),
	})
end

-- ========================= GENERAL RULES =========================== --

-- Ignore maximize requests from windows
hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Stop empty XWayland windows from stealing focus (fixes dragging issues)
hl.window_rule({
	name = "xwayland-fix",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
	},
	no_focus = true,
})

-- ========================= PICTURE IN PICTURE ====================== --

-- Floating, pinned PiP window in the top-left corner
hl.window_rule({
	name = "picture-in-picture",
	match = {
		title = "^(Picture-in-Picture)$",
	},
	float = true,
	pin = true,
	size = { 480, 270 },
	move = { 14, 12 },
})

-- ========================= FEISHIN ================================= --

-- Feishin → Workspace 11 (first workspace of the touch monitor)
hl.window_rule({
	name = "feishin-touch-display",
	match = {
		class = "^(feishin)$",
	},
	monitor = MON_TOUCH,
	workspace = ws(11, MON_TOUCH),
	fullscreen = false,
})

-- ========================= GAMING ================================== --

-- Steam games (class steam_app_<id>) open fullscreen
hl.window_rule({
	name = "steam-game-fullscreen",
	match = {
		class = "^steam_app_[1-9][0-9]*$",
	},
	float = false,
	fullscreen = true,
})

-- StarCraft II: fullscreen by title, for when the class doesn't match
hl.window_rule({
	name = "starcraft-2-fullscreen",
	match = {
		title = "^(StarCraft II)$",
	},
	float = false,
	fullscreen = true,
})

-- Brood War: fullscreen by title, for when the class doesn't match
hl.window_rule({
	name = "brood-war-fullscreen",
	match = {
		title = "^(Brood War)$",
	},
	float = false,
	fullscreen = true,
})

-- ========================= FILE PICKER ============================= --

-- lf file picker: centered floating window
hl.window_rule({
	name = "lf-file-picker",
	match = {
		class = "^(lf-picker)$",
	},
	float = true,
	center = true,
	size = { 1000, 650 },
})

-- ========================= AUTO PLACEMENT ========================== --

-- Alacritty titled "indy" → Workspace 8, main monitor
hl.window_rule({
	name = "indy-terminal",
	match = {
		class = "^Alacritty$",
		title = "^indy$",
	},
	workspace = ws(8, MON_MAIN),
})

-- Alacritty titled "Terminal" (the one startup-apps.sh opens) → Workspace 8, main monitor
-- Terminals with any other title open on whatever workspace you're on.
hl.window_rule({
	name = "main-terminal",
	match = {
		class = "^Alacritty$",
		title = "^Terminal$",
	},
	workspace = ws(8, MON_MAIN),
})

-- btop → Workspace 1, top monitor
place("btop-workspace", "^btop$", 1, MON_TOP)

-- Discord / Vesktop → Workspace 7, main monitor
place("vesktop-workspace", "^vesktop$", 7, MON_MAIN)

-- Steam client → Workspace 9, main monitor
place("steam-workspace", "^steam$", 9, MON_MAIN)

-- LibreWolf → Workspace 6, main monitor
place("librewolf-workspace", "^librewolf$", 6, MON_MAIN)

-- ========================= LAYER RULES ============================== --

-- Rofi: blur the background
hl.layer_rule({
	match = {
		namespace = "rofi",
	},
	blur = true,
	ignore_alpha = 0.5,
})

-- Notifications: blur the background
hl.layer_rule({
	match = {
		namespace = "notifications",
	},
	blur = true,
	ignore_alpha = 0.5,
})

-- Quickshell: blur the background
hl.layer_rule({
	match = {
		namespace = "quickshell",
	},
	blur = true,
	ignore_alpha = 0.5,
})
