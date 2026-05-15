-- See https://wiki.hypr.land/Configuring/Gestures

-- Workspace switching
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Window actions
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "down", action = "close" })

-- Floating toggle
hl.gesture({ fingers = 4, direction = "pinch", action = "float" })

-- Move windows
hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
