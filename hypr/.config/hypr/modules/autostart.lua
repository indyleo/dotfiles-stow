hl.on("hyprland.start", function()
	-- --- Launch Desktop ---
	hl.exec_cmd(barLaunch)
	hl.exec_cmd('hyprctl setcursor "Capitaine Cursors" 24')

	-- --- Launch Services ---
	hl.exec_cmd("sunshine")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("organizer.py -d")
	hl.exec_cmd("udiskie")
	hl.exec_cmd("medianotify")
	hl.exec_cmd(portal)
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME")
end)
