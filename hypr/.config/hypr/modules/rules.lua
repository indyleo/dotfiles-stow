-- ################################################################## --
-- __        ___           _                 ____        _            --
-- \ \      / (_)_ __   __| | _____      __ |  _ \ _   _| | ___  ___  --
--  \ \ /\ / /| | '_ \ / _` |/ _ \ \ /\ / / | |_) | | | | |/ _ \/ __| --
--   \ V  V / | | | | | (_| | (_) \ V  V /  |  _ <| |_| | |  __/\__ \ --
--    \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/   |_| \_\\__,_|_|\___||___/ --
-- ################################################################## --

-- ========================= MONITORS ================================ --

local MON_TOP = "HDMI-A-1"
local MON_MAIN = "DP-2"
local MON_TOUCH = "HDMI-A-4"

-- ========================= HELPERS ================================= --

-- hyprsplit-compatible workspace syntax
local function ws(number, monitor)
	return string.format("%d monitor:%s", number, monitor)
end

-- Application placement helper
local function place(name, class, workspace, monitor)
	hl.window_rule({
		name = name,
		match = { class = class },
		workspace = ws(workspace, monitor),
	})
end

-- ========================= GENERAL RULES =========================== --

-- Ignore maximize requests
hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix XWayland dragging
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

-- Pin Feishin to workspace 1 on the touch display
hl.window_rule({
	name = "feishin-touch-display",
	match = {
		class = "^(feishin)$",
	},
	monitor = MON_TOUCH,
	workspace = ws(1, MON_TOUCH),
	fullscreen = false,
})

-- ========================= GAMING ================================== --

-- Automatically fullscreen Steam games
hl.window_rule({
	name = "steam-game-fullscreen",
	match = {
		class = "^steam_app_[1-9][0-9]*$",
	},
	float = false,
	fullscreen = true,
})

-- StarCraft II fallback
hl.window_rule({
	name = "starcraft-2-fullscreen",
	match = {
		title = "^(StarCraft II)$",
	},
	float = false,
	fullscreen = true,
})

-- Brood War fallback
hl.window_rule({
	name = "brood-war-fullscreen",
	match = {
		title = "^(Brood War)$",
	},
	float = false,
	fullscreen = true,
})

-- ========================= FILE PICKER ============================= --

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

-- Alacritty indy terminals → Workspace 8, main monitor
hl.window_rule({
	name = "indy-terminal",
	match = {
		class = "^Alacritty$",
		title = "^indy$",
	},
	workspace = ws(8, MON_MAIN),
})

-- btop → Workspace 8, main monitor
place("btop-workspace", "^btop$", 8, MON_MAIN)

-- Discord / Vesktop → Workspace 7, main monitor
place("vesktop-workspace", "^vesktop$", 7, MON_MAIN)

-- Steam client → Workspace 9, main monitor
place("steam-workspace", "^steam$", 9, MON_MAIN)

-- LibreWolf → Workspace 6, main monitor
place("librewolf-workspace", "^librewolf$", 6, MON_MAIN)

-- ========================= LAYER RULES ============================== --

-- Rofi blur
hl.layer_rule({
	match = {
		namespace = "rofi",
	},
	blur = true,
	ignore_alpha = 0.5,
})

-- Notification blur
hl.layer_rule({
	match = {
		namespace = "notifications",
	},
	blur = true,
	ignore_alpha = 0.5,
})

-- Quickshell blur
hl.layer_rule({
	match = {
		namespace = "quickshell",
	},
	blur = true,
	ignore_alpha = 0.5,
})
