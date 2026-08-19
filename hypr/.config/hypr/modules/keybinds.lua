-- ################################################################## --
--  _   _                  _                 _    _  __               --
-- | | | |_   _ _ __  _ __| | __ _ _ __   __| |  | |/ /___ _   _ ___  --
-- | |_| | | | | '_ \| '__| |/ _` | '_ \ / _` |  | ' // _ \ | | / __| --
-- |  _  | |_| | |_) | |  | | (_| | | | | (_| |  | . \  __/ |_| \__ \ --
-- |_| |_|\__, | .__/|_|  |_|\__,_|_| |_|\__,_|  |_|\_\___|\__, |___/ --
--        |___/|_|                                         |___/      --
-- ################################################################## --

local mainMod = "SUPER"

-- --- Applications ---
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("vesktop"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("signal-desktop"))

-- --- Launchers ---
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call pick notes"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("qs ipc call pick emoji"))
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd("qs ipc call pick icon"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("qs ipc call powermenu toggle"))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("recorder"))

-- --- Window Management ---
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Focus & Layout
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.layout("addmaster"))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.layout("removemaster"))

-- --- System & Hardware ---
-- NOTE: these used to call `sysctl` directly; they now call into the
-- quickshell OSD (IpcHandler target "osd" in shell.qml), which runs the
-- actual wpctl/brightnessctl change command itself and pops the bar.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call osd briUp"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call osd briDown"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

-- Volume
hl.bind(mainMod .. " + ALT + Up", hl.dsp.exec_cmd("qs ipc call osd volUp"), { repeating = true })
hl.bind(mainMod .. " + ALT + Down", hl.dsp.exec_cmd("qs ipc call osd volDown"), { repeating = true })
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd("qs ipc call osd volToggle"), { repeating = true })
hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call osd volUp"), { repeating = true })
hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call osd volDown"), { repeating = true })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("qs ipc call osd volToggle"), { repeating = true })

-- Microphone
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.exec_cmd("qs ipc call osd micUp"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.exec_cmd("qs ipc call osd micDown"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("qs ipc call osd micToggle"), { repeating = true })
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call osd micUp"), { repeating = true })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call osd micDown"), { repeating = true })
hl.bind("SHIFT + XF86AudioMicMute", hl.dsp.exec_cmd("qs ipc call osd micToggle"), { repeating = true })

-- --- Media Controls (Song) ---
hl.bind(mainMod .. " + Right", hl.dsp.exec_cmd("mediactl --source song next"), { locked = true })
hl.bind(mainMod .. " + Left", hl.dsp.exec_cmd("mediactl --source song previous"), { locked = true })
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("mediactl --source song play-pause"), { locked = true })
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.exec_cmd("mediactl --source song skip 10"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.exec_cmd("mediactl --source song back 10"), { repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("mediactl --source song next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("mediactl --source song previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("mediactl --source song play-pause"), { locked = true })

-- --- Media Controls (Browser) ---
hl.bind(mainMod .. " + ALT + Right", hl.dsp.exec_cmd("mediactl --source browser next"), { locked = true })
hl.bind(mainMod .. " + ALT + Left", hl.dsp.exec_cmd("mediactl --source browser previous"), { locked = true })
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("mediactl --source browser play-pause"), { locked = true })
hl.bind(mainMod .. " + ALT + SHIFT + Right", hl.dsp.exec_cmd("mediactl --source browser skip 10"), { repeating = true })
hl.bind(mainMod .. " + ALT + SHIFT + Left", hl.dsp.exec_cmd("mediactl --source browser back 10"), { repeating = true })
hl.bind("ALT + XF86AudioNext", hl.dsp.exec_cmd("mediactl --source browser next"), { locked = true })
hl.bind("ALT + XF86AudioPrev", hl.dsp.exec_cmd("mediactl --source browser previous"), { locked = true })
hl.bind("ALT + XF86AudioPlay", hl.dsp.exec_cmd("mediactl --source browser play-pause"), { locked = true })

-- --- Screenshots & Recording ---
hl.bind("Print", hl.dsp.exec_cmd("qs ipc call screenshot region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("qs ipc call screenshot monitor"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("qs ipc call screenshot full"))
hl.bind(mainMod .. " + CTRL + Print", hl.dsp.exec_cmd("qs ipc call screenshot window"))
hl.bind(mainMod .. " + ALT + Print", hl.dsp.exec_cmd("qs ipc call screenshot color"))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("qs ipc call recording toggle"))

-- --- Wallpapers ---
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("desktopctl random ~/Pictures/Wallpapers/gruvbox"))

-- --- Workspaces (hyprsplit) ---
for i = 1, 5 do
	hl.bind(mainMod .. " + " .. i, hs.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. i, hs.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mainMod .. " + CTRL + D", hs.dsp.workspace.swap_monitors({ monitor1 = "current", monitor2 = "+1" }))
hl.bind(mainMod .. " + CTRL + G", hs.dsp.grab_rogue_windows())

-- --- Scratchpads ---
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(scratchpad .. " termsc"))
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd(scratchpad .. " lfsc lf"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(scratchpad .. " qalsc qalc"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(scratchpad .. " wiremixsc wiremix"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(scratchpad .. " gurks gurks"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(scratchpad .. " discordo discordo"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(scratchpad .. " twitch-tui twt"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(scratchpad .. " musicsc subsonic-tui"))

-- --- Mouse Binds ---
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
