-- ################################################################## --
-- __        ___           _                 ____        _            --
-- \ \      / (_)_ __   __| | _____      __ |  _ \ _   _| | ___  ___  --
--  \ \ /\ / /| | '_ \ / _` |/ _ \ \ /\ / / | |_) | | | | |/ _ \/ __| --
--   \ V  V / | | | | | (_| | (_) \ V  V /  |  _ <| |_| | |  __/\__ \ --
--    \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/   |_| \_\\__,_|_|\___||___/ --
-- ################################################################## --

-- See https://wiki.hypr.land/Configuring/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Workspace-Rules/ for workspace rules

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
