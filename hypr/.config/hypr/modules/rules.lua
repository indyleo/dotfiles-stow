-- ################################################################## --
-- __        ___           _                 ____        _            --
-- \ \      / (_)_ __   __| | _____      __ |  _ \ _   _| | ___  ___  --
--  \ \ /\ / /| | '_ \ / _` |/ _ \ \ /\ / / | |_) | | | | |/ _ \/ __| --
--   \ V  V / | | | | | (_| | (_) \ V  V /  |  _ <| |_| | |  __/\__ \ --
--    \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/   |_| \_\\__,_|_|\___||___/ --
-- ################################################################## --

-- --- Window Rules ---

-- Ignore maximize requests
hl.window_rule({
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix XWayland dragging
hl.window_rule({
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
	},
	no_focus = true,
})

-- Picture in picture
hl.window_rule({
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
	size = { 480, 270 },
	move = { 14, 12 },
})

-- Feishin: move to HDMI-A-4 (Touch Display) & workspace 1
hl.window_rule({
	match = { class = "^(feishin)$" },
	monitor = "HDMI-A-4",
	workspace = "1 monitor:HDMI-A-4",
	fullscreen = false,
})

-- Auto-fullscreen Steam games
hl.window_rule({
	match = { class = "^steam_app_[1-9][0-9]*$" },
	float = false,
	fullscreen = true,
})

-- SC2 / Brood War report class "steam_app_default", so the rule above
-- already catches them — but title-matching as an explicit fallback
-- in case Valve changes the class string on an update:
hl.window_rule({
	match = { title = "^(StarCraft II)$" },
	float = false,
	fullscreen = true,
})
hl.window_rule({
	match = { title = "^(Brood War)$" },
	float = false,
	fullscreen = true,
})

-- --- Layer Rules ---

-- Rofi blur
hl.layer_rule({
	match = { namespace = "rofi" },
	blur = true,
	ignore_alpha = 0.5,
})

-- Notifications blur
hl.layer_rule({
	match = { namespace = "notifications" },
	blur = true,
	ignore_alpha = 0.5,
})
