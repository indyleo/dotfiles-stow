import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

ShellRoot {
	id: root

	// --- Gruvbox Theme Colors ---
	readonly property color cal0:  "#282828" // Background (bg0)
	readonly property color cal1:  "#3c3836" // Pills (bg1)
	readonly property color cal2:  "#504945" // Pill BG (bg2)
	readonly property color cal3:  "#7c6f64" // Separators (bg3)

	readonly property color cal6:  "#ebdbb2" // Main Text (fg1)
	readonly property color cal7:  "#83a598" // Teal → Blue (storage/memory)
	readonly property color cal8:  "#fb4934" // Red
	readonly property color cal9:  "#d3869b" // Purple (system core)
	readonly property color cal10: "#fabd2f" // Gold → Yellow (power)
	readonly property color cal11: "#cc241d" // Alert Red (darker red)
	readonly property color cal13: "#b8bb26" // Green (network)
	readonly property color cal14: "#fe8019" // Orange (audio)
	readonly property color cal15: "#bdae93" // Silver (fg2)

	// Background for the OSD popups (vol/bri/mic + media), at 85% opacity
	// rather than fully solid.
	readonly property color osdBgColor: Qt.rgba(cal1.r, cal1.g, cal1.b, 0.85)

	property string fontFamily: "JetBrainsMono Nerd Font"
	property int fontSize: 13

	// --- Layout Data ---
	property string currentLayout: {
		const top = Hyprland.activeToplevel
		const focusedWs = Hyprland.focusedWorkspace
		if (!top || !focusedWs || top.workspace !== focusedWs) return "EMPTY"
		if (top.fullscreen) return "FULLSCREEN"
		if (top.floating) return "FLOATING"
		return "TILED"
	}

	// --- System Data Properties ---
	property string kernelIcon: ""
	property string kernelVersion: "..."
	property string cpuIcon: ""
	property string cpuText: "0%"
	property string gpuIcon: "󰢮"
	property string gpuText: "0%"
	property string memIcon: ""
	property string memText: "0%"
	property string diskIcon: "󰋊"
	property string diskText: "0%"

	// brightIcon/brightText/showBright removed -- now BrightnessController's
	// bright.icon / bright.text / bright.available (see below).

	property string batIcon: "󰢜"
	property string batText: "100%"
	property bool showBat: false

	property string ethIcon: "󰲜"
	property string ethText: "Disconnected"
	property bool showEth: false

	property string wifiIcon: "󰤮"
	property string wifiText: "Offline"
	property bool showWifi: true

	property string tailIcon: "󰈂"
	property string tailText: "Not connected"
	property bool showTail: false

	// volIcon/volText/micIcon/micText removed -- now AudioController's
	// audio.volIcon / audio.volText / audio.micIcon / audio.micText.

	// --- Screen/Media Data Properties ---
	property string sysMediaIcon: "" // Fallback icon if sysstats doesn't provide one
	property string sysMediaText: ""

	// --- Media Data (native MPRIS via Quickshell.Services.Mpris) ---
	// No mediactl/medianotify/playerctl subprocesses: MediaController reads
	// MPRIS directly over DBus and updates reactively on real state changes.
	MediaController { id: media }

	// --- Volume/Mic (native Pipewire) and Brightness (sysfs FileView) ---
	// No wpctl/raw-read subprocess chain: AudioController reads/writes
	// Pipewire directly; BrightnessController watches sysfs via inotify
	// and only shells out to brightnessctl to actually change the level.
	AudioController { id: audio }
	BrightnessController { id: bright }

	// --- Notifications (native org.freedesktop.Notifications daemon) --
	// Replaces mako. See NotificationController.qml for the mako ->
	// Quickshell config mapping. `notifs.popups` is the live ObjectModel
	// backing the top-right popup stack below; `notifs.history` is the
	// max-history=20 in-memory scrollback for the notification center.
	NotificationController { id: notifs }

	// --- Logic & Process Control ---
	Process { id: shellCmd }

	function parseSysstats(data, iconProp, textProp) {
		if (!data) return;
		let parts = data.trim().split(/\s+/);
		if (parts.length >= 1) root[iconProp] = parts[0];
		if (parts.length >= 2) root[textProp] = parts.slice(1).join(" ");
	}

	Process {
		id: kernelProc
		command: ["sysstats", "kernel"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "kernelIcon", "kernelVersion") }
	}

	Process {
		id: cpuProc
		command: ["sysstats", "cpu"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "cpuIcon", "cpuText") }
	}

	Process {
		id: gpuProc
		command: ["sysstats", "gpu"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "gpuIcon", "gpuText") }
	}

	Process {
		id: memProc
		command: ["sysstats", "mem"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "memIcon", "memText") }
	}

	Process {
		id: diskProc
		command: ["sysstats", "disk"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "diskIcon", "diskText") }
	}

	Process {
		id: batProc
		command: ["sysstats", "battery"]
		stdout: SplitParser {
			onRead: data => {
				// Catches "" (empty) and "No acpi" from your bash script
				if (!data || data.trim() === "" || data.includes("N/A") || data.includes("No") || data.includes("Not") || data.trim().endsWith(" 0%") || data.trim() === "0%") {
					root.showBat = false;
					return
				}
				root.showBat = true;
				root.parseSysstats(data, "batIcon", "batText")
			}
		}
	}

	Process {
		id: ethProc
		command: ["sysstats", "ethernet"]
		stdout: SplitParser {
			onRead: data => {
				if (!data) return;
				root.parseSysstats(data, "ethIcon", "ethText")
				root.showEth = data.includes("Connected")
			}
		}
	}

	Process {
		id: wifiProc
		command: ["sysstats", "wifi"]
		stdout: SplitParser {
			onRead: data => {
				if (!data) return;
				root.parseSysstats(data, "wifiIcon", "wifiText")
				let isWifiConnected = !data.includes("Offline") && !data.includes("No tool") && !data.includes("Disconnected");
				root.showWifi = isWifiConnected || !root.showEth;
			}
		}
	}

	Process {
		id: tailProc
		command: ["sysstats", "tail"]
		stdout: SplitParser {
			onRead: data => {
				if (!data) return;
				root.parseSysstats(data, "tailIcon", "tailText")
				root.showTail = data.includes("Connected") && !data.includes("Not connected")
			}
		}
	}

	// Media Process
	Process {
		id: sysMediaProc
		command: ["sysstats", "media"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "sysMediaIcon", "sysMediaText") }
	}

	Timer {
		interval: 2000;
		running: true; repeat: true; triggeredOnStart: true
		onTriggered: {
			cpuProc.running = false; cpuProc.running = true
			gpuProc.running = false; gpuProc.running = true
			kernelProc.running = false; kernelProc.running = true
			memProc.running = false; memProc.running = true
			diskProc.running = false; diskProc.running = true
			wifiProc.running = false; wifiProc.running = true
			ethProc.running = false; ethProc.running = true
			tailProc.running = false; tailProc.running = true
			batProc.running = false; batProc.running = true
			sysMediaProc.running = false; sysMediaProc.running = true
		}
	}


	// --- OSD (On-Screen Display) -----------------------------------
	// Mirrors the dwm osd.c / osds[] setup: an external keybind fires an
	// IPC call, which pops a bottom-center bar for OSD_TIMEOUT_MS.
	// Volume/mic go through AudioController (native Pipewire, no wpctl
	// subprocess to change OR read back). Brightness still shells out to
	// brightnessctl to write (sysfs perms), but BrightnessController
	// reads the result back via an inotify-watched FileView, not a
	// spawned "get" process.
	property bool osdVisible: false
	property string osdLabel: ""
	property int osdLevel: -1        // 0-100, or -1 for "no numeric level"
	property color osdAccent: cal14
	readonly property int osdTimeoutMs: 1200

	function osdShow(label, level, accent) {
		root.osdLabel = label;
		root.osdLevel = level;
		root.osdAccent = accent;
		root.osdVisible = true;
		osdHideTimer.restart();
	}

	Timer {
		id: osdHideTimer
		interval: root.osdTimeoutMs
		onTriggered: root.osdVisible = false
	}

	// Volume/mic/brightness pill icon+text (bar section below) bind
	// directly to audio.volIcon/audio.micIcon/bright.icon and friends --
	// no sync step needed here anymore. Those are plain property
	// bindings derived from the same reactive state the OSD itself
	// reads, so they update in the same tick as the OSD, with nothing
	// to debounce and no process to (re)spawn.

	// External trigger points -- bind these from hyprland.conf, e.g.:
	//   bindl = , XF86AudioRaiseVolume, exec, qs ipc call osd volUp
	// See osd.h's comment on osdtrigger() for the dwm-side equivalent.
	// Each function writes through its controller directly (property
	// assignment for audio, one brightnessctl call for brightness) and
	// pops the OSD off the value the controller hands back immediately
	// -- no separate "raw read" process in either path.
	IpcHandler {
		target: "osd"
		function volUp(): void     { const l = audio.volUp();     if (l >= 0) root.osdShow("VOL", l, root.cal14) }
		function volDown(): void   { const l = audio.volDown();   if (l >= 0) root.osdShow("VOL", l, root.cal14) }
		function volToggle(): void { const l = audio.volToggle(); if (l >= 0) root.osdShow("VOL", l, root.cal14) }
		function micUp(): void     { const l = audio.micUp();     if (l >= 0) root.osdShow("MIC", l, root.cal14) }
		function micDown(): void   { const l = audio.micDown();   if (l >= 0) root.osdShow("MIC", l, root.cal14) }
		function micToggle(): void { const l = audio.micToggle(); if (l >= 0) root.osdShow("MIC", l, root.cal14) }
		function briUp(): void     { root.osdShow("BRI", bright.up(), root.cal10) }
		function briDown(): void   { root.osdShow("BRI", bright.down(), root.cal10) }
	}

	// --- Media OSD ("Now Playing" popup) -----------------------------
	// Shows itself automatically whenever MediaController.nowPlaying()
	// fires (track change, resume/pause, switching active players) --
	// no polling needed since that signal is a direct consequence of
	// MPRIS's DBus PropertiesChanged. `media.ticking` is bound to
	// mosdVisible so the position timer (see MediaController.qml) only
	// runs while the popup is actually on screen.
	readonly property int mosdTimeoutMs: 3500
	property bool mosdVisible: false
	readonly property string mosdSourceIcon: media.activeType === "browser" ? "󰖟" : "󰝚"

	Timer {
		id: mosdHideTimer
		interval: root.mosdTimeoutMs
		onTriggered: root.mosdVisible = false
	}

	Binding { target: media; property: "ticking"; value: root.mosdVisible }

	function mosdShow() {
		root.mosdVisible = true;
		mosdHideTimer.restart();
	}

	Connections {
		target: media
		function onNowPlaying() { if (media.showMedia) root.mosdShow() }
	}

	// Manual/external trigger point, e.g. from a keybind:
	// qs ipc call mediaosd show
	IpcHandler {
		target: "mediaosd"
		function show(): void { root.mosdShow() }
	}

	// --- Notification center (history panel) --------------------------
	// Toggle from a keybind, e.g.:
	//   bindl = , XF86Notification, exec, qs ipc call notifcenter toggle
	property bool notifCenterVisible: false

	IpcHandler {
		target: "notifcenter"
		function toggle(): void { root.notifCenterVisible = !root.notifCenterVisible }
		function show(): void { root.notifCenterVisible = true }
		function hide(): void { root.notifCenterVisible = false }
		// mako-cli equivalents: `makoctl dismiss --all` / `makoctl history --clear`
		function dismissAll(): void { notifs.dismissAll() }
		function clearHistory(): void { notifs.clearHistory() }
	}

	Variants {
		model: Quickshell.screens

		PanelWindow {
			required property var modelData
			readonly property bool isPrimary: modelData === Quickshell.screens[0]

			readonly property string localActiveWindow: {
				const monitor = Hyprland.monitorFor(modelData);
				const top = Hyprland.activeToplevel;
				if (top && top.monitor && monitor && top.monitor.id === monitor.id) {
					return (top.title && top.title.trim() !== "") ? top.title.trim() : "Untitled";
				}
				return "Desktop";
			}

			screen: modelData
			anchors { top: true; left: true; right: true }
			implicitHeight: 34
			color: root.cal0

			RowLayout {
				anchors.fill: parent; spacing: 8; anchors.leftMargin: 12; anchors.rightMargin: 12

				// 0. The Locked Profile + Dynamic Play/Pause and Title Pill
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26
					Layout.preferredWidth: profileMediaLayout.implicitWidth + 12
					color: root.cal2
					radius: 13
					clip: true

					Behavior on Layout.preferredWidth {
						NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
					}

					RowLayout {
						id: profileMediaLayout
						anchors.fill: parent
						anchors.leftMargin: 6
						anchors.rightMargin: 6
						spacing: 8

						// 🖼️ Always-Visible Icon (Profile Pic)
						Item {
							Layout.preferredWidth: 22
							Layout.preferredHeight: 22
							Layout.alignment: Qt.AlignVCenter

							Image {
								id: profileImg
								anchors.fill: parent
								source: "icon.png"
								fillMode: Image.PreserveAspectCrop
								visible: false
							}
							Rectangle { id: profileMask; anchors.fill: parent; radius: width / 2; visible: false }
							OpacityMask { anchors.fill: parent; source: profileImg; maskSource: profileMask }
						}

						// 🎵 Dynamic Music Row
						RowLayout {
							visible: media.showMedia
							spacing: 8
							Layout.alignment: Qt.AlignVCenter

							Rectangle {
								width: 1
								height: 12
								color: root.cal3
							}

							// 📦 Music Thumbnail (Circular & Spinning)
							Item {
								Layout.preferredWidth: 22
								Layout.preferredHeight: 22

								Image {
									id: musicArt
									anchors.fill: parent
									source: media.displayArtUrl
									fillMode: Image.PreserveAspectCrop
									visible: false
									asynchronous: true
								}

								Rectangle {
									id: musicMask
									anchors.fill: parent
									radius: width / 2
									visible: false
								}

								OpacityMask {
									id: spinningArt
									anchors.fill: parent
									source: musicArt
									maskSource: musicMask
									visible: media.displayArtUrl !== ""

									// 🌀 Spins the circular thumbnail when playing
									RotationAnimation on rotation {
										id: spinAnim
										loops: Animation.Infinite
										from: spinningArt.rotation  // resume from current angle, no jarring reset
										to: spinningArt.rotation + 360
										duration: 5000
										running: media.isPlaying

										onRunningChanged: {
											if (running) {
												// re-anchor from/to from current position each time we resume
												from = spinningArt.rotation
												to = spinningArt.rotation + 360
											}
										}
									}
								}
							}

							// ▶️ Play/Pause Indicator Status
							Text {
								text: media.icon
								color: root.cal14
								font.pixelSize: root.fontSize + 2
								font.family: root.fontFamily
							}
							// 📜 Song Name (Scrolling Marquee)
							Item {
								Layout.preferredWidth: Math.min(180, songTxt.implicitWidth)
								Layout.preferredHeight: songTxt.implicitHeight
								clip: true

								Text {
									id: songTxt
									x: 0
									text: media.title
									color: root.cal6
									font.pixelSize: root.fontSize
									font.family: root.fontFamily
									onTextChanged: {
										songScrollAnim.stop()
										songTxt.x = 0
										if (songTxt.implicitWidth > 180)
										songScrollAnim.restart()
									}

									SequentialAnimation {
										id: songScrollAnim
										loops: Animation.Infinite
										running: songTxt.implicitWidth > 180 && media.isPlaying

										PauseAnimation { duration: 1000 }

										NumberAnimation {
											target: songTxt
											property: "x"
											from: 0
											to: -(songTxt.implicitWidth - 180)
											duration: (songTxt.implicitWidth - 180) * 30
										}

										PauseAnimation { duration: 1000 }

										NumberAnimation {
											target: songTxt
											property: "x"
											from: -(songTxt.implicitWidth - 180)
											to: 0
											duration: (songTxt.implicitWidth - 180) * 30
										}
									}
								}
							}
						}
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
						hoverEnabled: true

						onClicked: (m) => {
							if (media.showMedia) {
								if (m.button === Qt.LeftButton) {
									media.playPause()
								} else if (m.button === Qt.RightButton) {
									shellCmd.command = ["rofi", "-show", "drun"]
									shellCmd.running = false
									shellCmd.running = true
								} else if (m.button === Qt.MiddleButton) {
									shellCmd.command = ["sh", "-c", "power"]
									shellCmd.running = false
									shellCmd.running = true
								}
							} else {
								if (m.button === Qt.LeftButton) shellCmd.command = ["rofi", "-show", "drun"]
								else shellCmd.command = ["sh", "-c", "power"]
								shellCmd.running = false
								shellCmd.running = true
							}
						}

						onWheel: (wheel) => {
							if (media.showMedia) {
								if (wheel.angleDelta.y > 0) media.next()
								else media.previous()
							}
						}
					}
				}
				// 1. Layout
				Rectangle {
					Layout.preferredHeight: 26; Layout.preferredWidth: layoutText.implicitWidth + 24; color: root.cal2; radius: 13
					Text { id: layoutText; anchors.centerIn: parent; text: root.currentLayout; color: root.cal7; font.pixelSize: root.fontSize - 2; font.family: root.fontFamily; font.bold: true }
				}

				// 2. Window
				Rectangle {
					Layout.preferredHeight: 26; Layout.fillWidth: true; Layout.minimumWidth: 100; color: root.cal2; radius: 13; clip: true
					RowLayout {
						anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 10
						Text { text: localActiveWindow === "Desktop" ? "󰇄" : "󱂬"; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily }
						Text { Layout.fillWidth: true; text: localActiveWindow; color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
					}
				}
				// 2.5 Screen/Media Status Pill
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26
					Layout.preferredWidth: sysMediaRow.implicitWidth + 24
					color: root.cal2
					radius: 13

					Row {
						id: sysMediaRow
						anchors.centerIn: parent
						spacing: 0
						property bool pinned: false
						property bool hovered: false
						readonly property bool expanded: pinned || hovered

						Text {
							text: root.sysMediaIcon
							color: root.cal10 // Uses the yellow system color
							font.pixelSize: root.fontSize + 2
							font.family: root.fontFamily
							anchors.verticalCenter: parent.verticalCenter
						}

						Item {
							height: 20
							width: parent.expanded ? sysMediaTxt.implicitWidth + 8 : 0
							clip: true
							anchors.verticalCenter: parent.verticalCenter
							Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

							Text {
								id: sysMediaTxt
								anchors.left: parent.left
								anchors.leftMargin: 6
								anchors.verticalCenter: parent.verticalCenter
								text: root.sysMediaText
								color: root.cal10
								font.pixelSize: root.fontSize
								font.family: root.fontFamily
								opacity: parent.width > 5 ? 1 : 0
								Behavior on opacity { NumberAnimation { duration: 200 } }
							}
						}
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.MiddleButton
						hoverEnabled: true
						onEntered: sysMediaRow.hovered = true
						onExited: sysMediaRow.hovered = false
						onClicked: (m) => {
							if (m.button === Qt.MiddleButton) {
								sysMediaRow.pinned = !sysMediaRow.pinned
							} else if (m.button === Qt.LeftButton) {
								shellCmd.command = ["sh", "-c", "recorder"]
								shellCmd.running = false
								shellCmd.running = true
							}
						}
					}
				}

				// 3. Stats
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26; Layout.preferredWidth: statsRow.implicitWidth + 30; color: root.cal2; radius: 13
					RowLayout {
						id: statsRow; anchors.centerIn: parent; spacing: 12

						// Kernel
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: kernelRow.width
							Row {
								id: kernelRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.kernelIcon; color: root.cal9; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? kernelTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: kernelTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.kernelVersion; color: root.cal9; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: kernelRow.hovered = true; onExited: kernelRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) kernelRow.pinned = !kernelRow.pinned } }
						}

						// CPU
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: cpuRow.width
							Row {
								id: cpuRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.cpuIcon; color: root.cal9; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? cpuTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: cpuTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.cpuText; color: root.cal9; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: cpuRow.hovered = true; onExited: cpuRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) cpuRow.pinned = !cpuRow.pinned; } }
						}

						// GPU
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: gpuRow.width
							Row {
								id: gpuRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.gpuIcon; color: root.cal9; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? gpuTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: gpuTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.gpuText; color: root.cal9; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: gpuRow.hovered = true; onExited: gpuRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) gpuRow.pinned = !gpuRow.pinned; } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3 }

						// RAM
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: memRow.width
							Row {
								id: memRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.memIcon; color: root.cal7; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? memTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: memTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.memText; color: root.cal7; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton; hoverEnabled: true; onEntered: memRow.hovered = true; onExited: memRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) memRow.pinned = !memRow.pinned; else if (m.button === Qt.LeftButton) { memProc.running = false; memProc.running = true } } }
						}

						// Disk
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: diskRow.width
							Row {
								id: diskRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.diskIcon; color: root.cal7; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? diskTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: diskTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.diskText; color: root.cal7; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: diskRow.hovered = true; onExited: diskRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) diskRow.pinned = !diskRow.pinned; } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3; visible: bright.available || root.showBat }

						// Brightness
						Item {
							visible: bright.available
							Layout.preferredHeight: 20; Layout.preferredWidth: brightRow.width
							Row {
								id: brightRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: bright.icon; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? brightTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: brightTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: bright.text; color: root.cal10; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: brightRow.hovered = true; onExited: brightRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) brightRow.pinned = !brightRow.pinned } }
						}

						// Battery
						Rectangle { width: 1; height: 12; color: root.cal3; visible: root.showBat && bright.available }
						Item {
							visible: root.showBat; Layout.preferredHeight: 20; Layout.preferredWidth: batRow.width
							Row {
								id: batRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.batIcon; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? batTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: batTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.batText; color: root.cal10; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: batRow.hovered = true; onExited: batRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) batRow.pinned = !batRow.pinned } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3; visible: (root.showEth || root.showWifi || root.showTail) }

						// Ethernet
						Item {
							visible: root.showEth
							Layout.preferredHeight: 20; Layout.preferredWidth: ethRow.width
							Row {
								id: ethRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.ethIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? ethTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: ethTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.ethText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: ethRow.hovered = true; onExited: ethRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) ethRow.pinned = !ethRow.pinned; else if (m.button === Qt.RightButton) { shellCmd.command = ["nm-connection-editor"]; shellCmd.running = false; shellCmd.running = true } } }
						}

						// WIFI
						Item {
							visible: root.showWifi
							Layout.preferredHeight: 20; Layout.preferredWidth: wifiRow.width
							Row {
								id: wifiRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.wifiIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? wifiTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: wifiTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.wifiText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: wifiRow.hovered = true; onExited: wifiRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) wifiRow.pinned = !wifiRow.pinned; else if (m.button === Qt.LeftButton) { shellCmd.command = ["sh", "-c", "wifi"]; shellCmd.running = false; shellCmd.running = true } else if (m.button === Qt.RightButton) { shellCmd.command = ["nm-connection-editor"]; shellCmd.running = false; shellCmd.running = true } } }
						}

						// Tailscale
						Item {
							visible: root.showTail
							Layout.preferredHeight: 20; Layout.preferredWidth: tailRow.width
							Row {
								id: tailRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.tailIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? tailTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: tailTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.tailText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: tailRow.hovered = true; onExited: tailRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) tailRow.pinned = !tailRow.pinned } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3 }

						// Microphone
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: micRow.width
							Row {
								id: micRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: audio.micIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? micTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: micTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: audio.micText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: micRow.hovered = true; onExited: micRow.hovered = false; onWheel: (wheel) => { if (wheel.angleDelta.y > 0) audio.micUp(); else audio.micDown() }; onClicked: (m) => { if(m.button === Qt.MiddleButton) micRow.pinned = !micRow.pinned; else if (m.button === Qt.LeftButton) { audio.micToggle() } else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol", "-t", "4"]; shellCmd.running = false; shellCmd.running = true } } }
						}

						// Volume
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: volRow.width
							Row {
								id: volRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: audio.volIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? volTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: volTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: audio.volText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: volRow.hovered = true; onExited: volRow.hovered = false; onWheel: (wheel) => { if (wheel.angleDelta.y > 0) audio.volUp(); else audio.volDown() }; onClicked: (m) => { if(m.button === Qt.MiddleButton) volRow.pinned = !volRow.pinned; else if (m.button === Qt.LeftButton) { audio.volToggle() } else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol", "-t", "3"]; shellCmd.running = false; shellCmd.running = true } } }
						}
					}
				}

				// 4. Clock
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26; Layout.preferredWidth: clockText.implicitWidth + 30; color: root.cal2; radius: 13
					Text {
						id: clockText; anchors.centerIn: parent; property var dateTime: new Date(); text: Qt.formatDateTime(dateTime, "󰥔  hh:mm AP |   dddd MMMM dd yyyy")
						color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
						Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.dateTime = new Date() }
					}
				}

				// 5. Notification center toggle -- left-click opens/closes the
				// history panel, right-click dismisses every live popup. The
				// small dot lights up while there's at least one un-dismissed
				// notification, same "accent-only" language as the rest of the bar.
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26; Layout.preferredWidth: 26; radius: 13
					color: root.notifCenterVisible ? root.cal3 : root.cal2

					Text {
						anchors.centerIn: parent
						text: notifs.popups.values.length > 0 ? "\uf0f3" : "\uf0a2" // bell / bell-outline (nerd font fa)
						color: root.notifCenterVisible ? root.cal7 : root.cal6
						font.pixelSize: root.fontSize + 2
						font.family: root.fontFamily
					}

					Rectangle {
						visible: notifs.popups.values.length > 0
						width: 8; height: 8; radius: 4
						color: root.cal11
						border.width: 1; border.color: root.cal0
						anchors.top: parent.top; anchors.right: parent.right
						anchors.topMargin: -1; anchors.rightMargin: -1
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.RightButton
						onClicked: (m) => {
							if (m.button === Qt.LeftButton) root.notifCenterVisible = !root.notifCenterVisible
							else if (m.button === Qt.RightButton) notifs.dismissAll()
						}
					}
				}
			}
		}
	}

	// --- OSD popup window (bottom-center, primary screen only) --------
	PanelWindow {
		id: osdWindow
		screen: Quickshell.screens[0]
		visible: root.osdVisible
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay

		anchors { left: true; right: true; bottom: true }
		margins.bottom: 48
		implicitHeight: 44

		Rectangle {
			width: 260
			height: 44
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			color: root.osdBgColor
			radius: 10
			border.width: 2
			border.color: root.osdAccent

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 12
				anchors.rightMargin: 12
				spacing: 10

				Text {
					text: root.osdLabel
					color: root.cal6
					font.pixelSize: root.fontSize
					font.family: root.fontFamily
					font.bold: true
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 10
					radius: 5
					color: root.cal3
					clip: true

					Rectangle {
						anchors.left: parent.left
						anchors.top: parent.top
						anchors.bottom: parent.bottom
						radius: 5
						width: root.osdLevel >= 0 ? parent.width * Math.min(root.osdLevel, 100) / 100 : 0
						color: root.osdAccent
						Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
					}
				}
			}
		}
	}

	// --- Media OSD popup window ("Now Playing", primary screen only) --
	PanelWindow {
		id: mosdWindow
		screen: Quickshell.screens[0]
		visible: root.mosdVisible
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay

		anchors { left: true; right: true; bottom: true }
		margins.bottom: 110 // taller than the 48px vol/bri/mic OSD so they don't overlap
		implicitHeight: 122

		Rectangle {
			width: 460
			height: 122
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			color: root.osdBgColor
			radius: 12
			border.width: 2
			border.color: root.cal14

			RowLayout {
				anchors.fill: parent
				anchors.margins: 14
				spacing: 14

				// Album art thumbnail
				Item {
					Layout.preferredWidth: 80
					Layout.preferredHeight: 80
					Layout.alignment: Qt.AlignVCenter

					Rectangle {
						anchors.fill: parent
						radius: 8
						color: root.cal2
						visible: media.displayArtUrl === ""
					}

					Image {
						id: mosdArt
						anchors.fill: parent
						source: media.displayArtUrl
						fillMode: Image.PreserveAspectCrop
						visible: false
						asynchronous: true
					}
					Rectangle { id: mosdArtMask; anchors.fill: parent; radius: 8; visible: false }
					OpacityMask {
						anchors.fill: parent
						source: mosdArt
						maskSource: mosdArtMask
						visible: media.displayArtUrl !== ""
					}
				}

				ColumnLayout {
					Layout.fillWidth: true
					Layout.fillHeight: true
					spacing: 4

					RowLayout {
						spacing: 6
						Layout.fillWidth: true

						Text { text: root.mosdSourceIcon; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily }
						Text { text: media.icon; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily }
						Text {
							Layout.fillWidth: true
							text: media.title
							color: root.cal6; font.pixelSize: root.fontSize + 1; font.family: root.fontFamily; font.bold: true
							elide: Text.ElideRight
						}
					}

					Text {
						Layout.fillWidth: true
						text: {
							const hasArtist = media.artist !== "";
							const hasAlbum = media.album !== "";
							if (hasArtist && hasAlbum) return media.artist + " — " + media.album;
							if (hasArtist) return media.artist;
							return "";
						}
						color: root.cal15; font.pixelSize: root.fontSize - 1; font.family: root.fontFamily
						elide: Text.ElideRight
					}

					Item { Layout.fillHeight: true }

					Text {
						Layout.alignment: Qt.AlignRight
						visible: media.progressTime !== ""
						text: media.progressTime
						color: root.cal15; font.pixelSize: root.fontSize - 2; font.family: root.fontFamily
					}

					Rectangle {
						Layout.fillWidth: true
						Layout.preferredHeight: 6
						radius: 3
						color: root.cal3
						clip: true

						Rectangle {
							anchors.left: parent.left
							anchors.top: parent.top
							anchors.bottom: parent.bottom
							radius: 3
							width: media.progressPct >= 0 ? parent.width * Math.min(media.progressPct, 100) / 100 : 0
							color: root.cal14
							Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.Linear } }
						}
					}
				}
			}
		}
	}

	// --- Notification urgency accents ----------------------------------
	// Same idea as osdAccent/mosd's per-type accent color (cal14 for
	// vol/mic, cal10 for brightness): one consistent card chrome
	// (osdBgColor + cal7 border, same as every other popup in this
	// shell) with only the accent swapping per urgency, rather than
	// mako's approach of recoloring the whole card background.
	function notifBorder(urgency) {
		if (urgency === NotificationUrgency.Critical) return root.cal11
		if (urgency === NotificationUrgency.Low) return root.cal3
		return root.cal7 // normal
	}
	function notifAccentText(urgency) {
		return urgency === NotificationUrgency.Critical ? root.cal8 : root.cal6
	}

	// --- Notification popups (top-right stack) -------------------------
	// Mirrors mako's `anchor=top-right`, `border-radius=10`, `border-size=2`,
	// and the "persist until dismissed unless the app sets its own
	// expire-timeout" behavior -- but chrome/type/alignment match the
	// rest of this shell (osdBgColor, JetBrainsMono Nerd Font, left-aligned)
	// rather than mako's own font/centering/palette.
	PanelWindow {
		id: notifWindow
		screen: Quickshell.screens[0]
		visible: notifColumn.count > 0
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay

		anchors { top: true; right: true }
		margins.top: 42
		margins.right: 12
		implicitWidth: 340
		implicitHeight: notifColumn.implicitHeight

		ColumnLayout {
			id: notifColumn
			readonly property int count: notifs.popups.values.length
			width: 340
			spacing: 8

			Repeater {
				model: notifs.popups

				delegate: Rectangle {
					id: notifCard
					required property Notification modelData

					Layout.preferredWidth: 340
					Layout.preferredHeight: notifContent.implicitHeight + 16 // padding=8 top+bottom
					radius: 10 // border-radius=10, matches osdWindow's pill radius
					color: root.osdBgColor // same translucent bg1 as every other popup
					border.width: 2 // border-size=2
					border.color: root.notifBorder(modelData.urgency)
					clip: true

					// Auto-dismiss only if the sender requested a timeout
					// (mako behavior with no default-timeout configured).
					Timer {
						running: notifCard.modelData.expireTimeout > 0
						interval: notifCard.modelData.expireTimeout * 1000
						onTriggered: notifCard.modelData.expire()
					}

					// on-button-left=dismiss / -right=dismiss-all / -middle=invoke-default-action
					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
						cursorShape: Qt.PointingHandCursor
						onClicked: mouse => {
							if (mouse.button === Qt.LeftButton) notifCard.modelData.dismiss()
							else if (mouse.button === Qt.RightButton) notifs.dismissAll()
							else if (mouse.button === Qt.MiddleButton) notifs.invokeDefaultAction(notifCard.modelData)
						}
					}

					RowLayout {
						id: notifContent
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						anchors.leftMargin: 10
						anchors.rightMargin: 10
						spacing: 10

						// icons=1 -- image hint takes priority over the app icon,
						// same preference order mako uses. Same square-with-
						// placeholder-bg treatment as the media OSD's album art.
						Item {
							visible: notifCard.modelData.image !== "" || notifCard.modelData.appIcon !== ""
							Layout.preferredWidth: 36
							Layout.preferredHeight: 36
							Layout.alignment: Qt.AlignVCenter

							Rectangle {
								anchors.fill: parent
								radius: 8
								color: root.cal2
							}
							Image {
								anchors.fill: parent
								visible: notifCard.modelData.image !== ""
								source: notifCard.modelData.image
								fillMode: Image.PreserveAspectCrop
								asynchronous: true
							}
							IconImage {
								anchors.fill: parent
								anchors.margins: notifCard.modelData.image === "" ? 6 : 0
								visible: notifCard.modelData.image === "" && notifCard.modelData.appIcon !== ""
								source: Quickshell.iconPath(notifCard.modelData.appIcon, "")
							}
						}

						ColumnLayout {
							Layout.fillWidth: true
							spacing: 3

							Text {
								Layout.fillWidth: true
								text: notifCard.modelData.summary
								color: root.notifAccentText(notifCard.modelData.urgency)
								font.family: root.fontFamily
								font.pixelSize: root.fontSize
								font.bold: true
								horizontalAlignment: Text.AlignHCenter // mako/dunst-style centered text
								wrapMode: Text.Wrap
								elide: Text.ElideRight
								maximumLineCount: 2
							}

							Text {
								Layout.fillWidth: true
								visible: notifCard.modelData.body !== ""
								text: notifCard.modelData.body
								textFormat: Text.StyledText // markup=1
								color: root.cal15
								font.family: root.fontFamily
								font.pixelSize: root.fontSize - 2
								horizontalAlignment: Text.AlignHCenter // mako/dunst-style centered text
								wrapMode: Text.Wrap
								elide: Text.ElideRight
								maximumLineCount: 4
							}

							// progress-color -- shown when the sender attaches a
							// "value" hint (0-100), e.g. volume/brightness bridges.
							// Same track/fill treatment as the OSD/media-OSD bars.
							Rectangle {
								visible: notifs.hasProgress(notifCard.modelData)
								Layout.fillWidth: true
								Layout.preferredHeight: 6
								radius: 3
								color: root.cal3
								clip: true

								Rectangle {
									anchors.left: parent.left
									anchors.top: parent.top
									anchors.bottom: parent.bottom
									radius: 3
									width: parent.width * Math.min(Math.max(notifCard.modelData.hints.value ?? 0, 0), 100) / 100
									color: root.notifBorder(notifCard.modelData.urgency)
									Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
								}
							}
						}
					}
				}
			}
		}
	}

	// --- Notification center (history panel) ---------------------------
	// Toggled via `qs ipc call notifcenter toggle`. Shows the last
	// historyLimit (mako: max-history=20) notifications, newest first.
	PanelWindow {
		id: notifCenterWindow
		screen: Quickshell.screens[0]
		visible: root.notifCenterVisible
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay

		anchors { top: true; right: true; bottom: true }
		margins.top: 42
		margins.right: 12
		margins.bottom: 12
		implicitWidth: 340

		Rectangle {
			anchors.fill: parent
			radius: 10
			color: root.osdBgColor
			border.width: 2
			border.color: root.cal7

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 10
				spacing: 8

				RowLayout {
					Layout.fillWidth: true
					Text {
						Layout.fillWidth: true
						text: "Notifications"
						color: root.cal6
						font.family: root.fontFamily
						font.pixelSize: root.fontSize
						font.bold: true
					}
					Text {
						text: "Clear"
						color: root.cal8
						font.family: root.fontFamily
						font.pixelSize: root.fontSize - 1
						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							onClicked: notifs.clearHistory()
						}
					}
				}

				Rectangle { Layout.fillWidth: true; height: 1; color: root.cal3 }

				ListView {
					Layout.fillWidth: true
					Layout.fillHeight: true
					clip: true
					spacing: 6
					model: notifs.history

					Text {
						visible: notifs.history.length === 0
						anchors.centerIn: parent
						text: "No notifications"
						color: root.cal15
						font.family: root.fontFamily
						font.pixelSize: root.fontSize - 1
					}

					delegate: Rectangle {
						required property var modelData
						width: ListView.view.width
						height: histRow.implicitHeight + 12
						radius: 8
						color: root.cal2

						RowLayout {
							id: histRow
							anchors.fill: parent
							anchors.margins: 6
							spacing: 8

							// Notification Image / Icon
							Item {
								visible: (modelData.image && modelData.image !== "") || (modelData.appIcon && modelData.appIcon !== "")
								Layout.preferredWidth: 32
								Layout.preferredHeight: 32
								Layout.alignment: Qt.AlignVCenter

								Rectangle {
									anchors.fill: parent
									radius: 6
									color: root.cal1
								}
								Image {
									anchors.fill: parent
									visible: modelData.image && modelData.image !== ""
									source: modelData.image || ""
									fillMode: Image.PreserveAspectCrop
									asynchronous: true
								}
								IconImage {
									anchors.fill: parent
									anchors.margins: (modelData.image && modelData.image !== "") ? 0 : 4
									visible: (!modelData.image || modelData.image === "") && (modelData.appIcon && modelData.appIcon !== "")
									source: Quickshell.iconPath(modelData.appIcon || "", "")
								}
							}

							ColumnLayout {
								Layout.fillWidth: true
								spacing: 2
								// Summary (App name removed, markup enabled)
								Text {
									Layout.fillWidth: true
									text: modelData.summary
									textFormat: Text.StyledText
									color: root.cal6
									font.family: root.fontFamily
									font.pixelSize: root.fontSize - 1
									font.bold: true
									horizontalAlignment: Text.AlignHCenter
									wrapMode: Text.Wrap
									elide: Text.ElideRight
									maximumLineCount: 2
								}

								// Body (Markup/Formatting enabled)
								Text {
									Layout.fillWidth: true
									visible: modelData.body !== ""
									text: modelData.body
									textFormat: Text.StyledText
									color: root.cal15
									font.family: root.fontFamily
									font.pixelSize: root.fontSize - 2
									horizontalAlignment: Text.AlignHCenter
									wrapMode: Text.Wrap
									maximumLineCount: 4
									elide: Text.ElideRight
								}

							}
						}
					}
				}
			}
		}
	}
}
