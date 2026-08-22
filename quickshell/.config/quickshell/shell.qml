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

	// Colors
	readonly property color cal0:  "#282828"
	readonly property color cal1:  "#3c3836"
	readonly property color cal2:  "#504945"
	readonly property color cal3:  "#7c6f64"
	readonly property color cal4:  "#a89984"
	readonly property color cal5:  "#d5c4a1"
	readonly property color cal6:  "#ebdbb2"
	readonly property color cal7:  "#83a598"
	readonly property color cal8:  "#fb4934"
	readonly property color cal9:  "#d3869b"
	readonly property color cal10: "#fabd2f"
	readonly property color cal11: "#cc241d"
	readonly property color cal12: "#458588"
	readonly property color cal13: "#b8bb26"
	readonly property color cal14: "#fe8019"
	readonly property color cal15: "#bdae93"

	readonly property color osdBgColor: Qt.rgba(cal1.r, cal1.g, cal1.b, 0.85)

	property string fontFamily: "JetBrainsMono Nerd Font"
	property int fontSize: 13

	property string currentLayout: {
		const top = Hyprland.activeToplevel
		const focusedWs = Hyprland.focusedWorkspace
		if (!top || !focusedWs || top.workspace.id !== focusedWs.id) return "EMPTY"
		if (top.fullscreen) return "FULLSCREEN"
		if (top.floating) return "FLOATING"
		return "TILED"
	}

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
	property string ethIcon: "󰲜"
	property string ethText: "Disconnected"
	property bool showEth: false
	property string wifiIcon: "󰤮"
	property string wifiText: "Offline"
	property bool showWifi: true
	property string tailIcon: "󰈂"
	property string tailText: "Not connected"
	property bool showTail: false
	property string weatherIcon: "󰖐"
	property string weatherText: "--"

	// All the stat pills above depend on an external "sysstats" script.
	// Previously, if it wasn't installed, every pill just kept showing its
	// initial placeholder ("0%", "Disconnected", etc.) forever with no
	// indication those were placeholders and not real readings - "0%" in
	// particular looks exactly like a genuine zero reading. This flag lets
	// the pills distinguish "not checked yet" from "confirmed missing".
	property bool sysstatsAvailable: true

	property string sysMediaText: ""

	property bool notifCenterVisible: false
	property bool powerMenuVisible: false
	property bool sysMonVisible: false

	MediaController { id: media }
	AudioController { id: audio }
	BrightnessController { id: bright }
	NotificationController { id: notifs }
	BatteryController { id: battery }
	SystemMonitor { id: sysMon; active: root.sysMonVisible; screenshotProvider: screenshot; screenRecorder: screenRecorder }
	PowerController { id: powerController }
	ClipboardController { id: clipboard }
	WifiManager { id: wifiManager }
	AppLauncher { id: appLauncher }
	Dmenu { id: dmenu }
	WeatherController { id: weather }
	ScreenshotController { id: screenshot }
	ScreenRecorder { id: screenRecorder }
	EmojiPicker { id: emojiPicker }
	NerdFontPicker { id: nerdFontPicker }
	NotesPicker { id: notesPicker }
	AudioSwitcher { id: audioSwitcher }
	AudioMixer { id: audioMixer }
	Connections { target: audioSwitcher; function onRequestMixer() { audioMixer.active = true } }
	Connections { target: audioMixer; function onRequestSwitcher() { audioSwitcher.active = true } }

	property var notifBorder: (urgency) => {
		switch (urgency) {
			case NotificationUrgency.Critical: return root.cal8
			case NotificationUrgency.Low:      return root.cal3
			default:                           return root.cal14
		}
	}
	property var notifAccentText: (urgency) => {
		switch (urgency) {
			case NotificationUrgency.Critical: return root.cal8
			case NotificationUrgency.Low:      return root.cal15
			default:                           return root.cal6
		}
	}

	Process { id: shellCmd }

	Process {
		id: detectSysstatsProc
		running: true
		command: ["sh", "-c", "command -v sysstats >/dev/null 2>&1 && echo yes || echo no"]
		stdout: StdioCollector {
			onStreamFinished: {
				root.sysstatsAvailable = text.trim() === "yes"
				if (!root.sysstatsAvailable) {
					console.warn("[shell] 'sysstats' not found on PATH - stat pills (CPU, GPU, memory, disk, network) will show N/A")
					root.cpuText = "N/A"
					root.gpuText = "N/A"
					root.memText = "N/A"
					root.diskText = "N/A"
					root.ethText = "N/A"
					root.wifiText = "N/A"
					root.tailText = "N/A"
					root.weatherText = "N/A"
					root.kernelVersion = "N/A"
				}
			}
		}
	}

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
	Process { id: cpuProc; command: ["sysstats", "cpu"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "cpuIcon", "cpuText") } }
	Process { id: gpuProc; command: ["sysstats", "gpu"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "gpuIcon", "gpuText") } }
	Process { id: memProc; command: ["sysstats", "mem"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "memIcon", "memText") } }
	Process { id: diskProc; command: ["sysstats", "disk"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "diskIcon", "diskText") } }
	Process { id: weatherStatProc; command: ["sysstats", "weather"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "weatherIcon", "weatherText") } }
	Process {
		id: ethProc
		command: ["sysstats", "ethernet"]
		stdout: SplitParser {
			onRead: data => {
				if (!data) return;
				root.parseSysstats(data, "ethIcon", "ethText")
				root.showEth = data.includes("Connected") && !data.includes("Disconnected")
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

	Timer {
		interval: 2000; running: root.sysstatsAvailable; repeat: true; triggeredOnStart: true
		onTriggered: {
			cpuProc.running = false; cpuProc.running = true
			memProc.running = false; memProc.running = true
			diskProc.running = false; diskProc.running = true
			wifiProc.running = false; wifiProc.running = true
			ethProc.running = false; ethProc.running = true
			tailProc.running = false; tailProc.running = true
		}
	}
	Timer {
		interval: 60000; running: root.sysstatsAvailable; repeat: true; triggeredOnStart: true
		onTriggered: {
			kernelProc.running = false; kernelProc.running = true
			gpuProc.running = false; gpuProc.running = true
			weatherStatProc.running = false; weatherStatProc.running = true
		}
	}

	// OSD
	property bool osdVisible: false
	property string osdLabel: ""
	property int osdLevel: -1
	property color osdAccent: cal14
	readonly property int osdTimeoutMs: 1200

	function osdShow(label, level, accent) {
		root.osdLabel = label;
		root.osdLevel = level;
		root.osdAccent = accent;
		root.osdVisible = true;
		osdHideTimer.restart();
	}

	Timer { id: osdHideTimer; interval: root.osdTimeoutMs; onTriggered: root.osdVisible = false }

	// Osd's IPC
	IpcHandler {
		target: "osd"
		function volUp(): void     { const l = audio.volUp();     if (l >= 0) root.osdShow("VOL", l, root.cal14) }
		function volDown(): void   { const l = audio.volDown();   if (l >= 0) root.osdShow("VOL", l, root.cal14) }
		function volToggle(): void { const l = audio.volToggle(); if (l >= 0) root.osdShow("VOL", l, root.cal14) }
		function micUp(): void     { const l = audio.micUp();     if (l >= 0) root.osdShow("MIC", l, root.cal14) }
		function micDown(): void   { const l = audio.micDown();   if (l >= 0) root.osdShow("MIC", l, root.cal14) }
		function micToggle(): void { const l = audio.micToggle(); if (l >= 0) root.osdShow("MIC", l, root.cal14) }
		function briUp(): void     { const l = bright.up();       if (l >= 0) root.osdShow("BRI", l, root.cal10) }
		function briDown(): void   { const l = bright.down();     if (l >= 0) root.osdShow("BRI", l, root.cal10) }
	}

	readonly property int mosdTimeoutMs: 3500
	property bool mosdVisible: false
	readonly property string mosdSourceIcon: media.activeType === "browser" ? "󰖟" : "󰝚"

	Timer { id: mosdHideTimer; interval: root.mosdTimeoutMs; onTriggered: root.mosdVisible = false }
	Binding { target: media; property: "ticking"; value: root.mosdVisible || root.notifCenterVisible }

	function mosdShow() {
		root.mosdVisible = true;
		mosdHideTimer.restart();
	}

	Connections { target: media; function onNowPlaying() { if (media.showMedia) root.mosdShow() } }

	// Media OSD
	IpcHandler { target: "mediaosd"; function show(): void { root.mosdShow() } }

	// Notification center
	IpcHandler {
		target: "notifcenter"
		function toggle(): void { root.notifCenterVisible = !root.notifCenterVisible }
		function show(): void { root.notifCenterVisible = true }
		function hide(): void { root.notifCenterVisible = false }
		function dismissAll(): void { notifs.dismissAll() }
		function clearHistory(): void { notifs.clearHistory() }
	}

	// Power Menu
	IpcHandler {
		target: "powermenu"
		function toggle(): void { root.powerMenuVisible = !root.powerMenuVisible }
		function show(): void { root.powerMenuVisible = true }
		function hide(): void { root.powerMenuVisible = false }
	}

	// System Monitor
	IpcHandler {
		target: "sysmon"
		function toggle(): void { root.sysMonVisible = !root.sysMonVisible }
		function show(): void { root.sysMonVisible = true }
		function hide(): void { root.sysMonVisible = false }
	}

	// Clipboard
	IpcHandler {
		target: "clipboard"
		function toggle(): void { clipboard.active = !clipboard.active }
		function show(): void { clipboard.active = true }
		function hide(): void { clipboard.active = false }
	}

	// Wifi
	IpcHandler {
		target: "wifi"
		function toggle(): void { wifiManager.active = !wifiManager.active }
		function show(): void { wifiManager.active = true }
		function hide(): void { wifiManager.active = false }
	}

	// Weather
	IpcHandler {
		target: "weather"
		function toggle(): void { weather.active = !weather.active }
		function show(): void { weather.active = true }
		function hide(): void { weather.active = false }
	}

	// Screenshot
	IpcHandler {
		target: "screenshot"
		function full(): void    { screenshot.screenshotFull() }
		function window(): void  { screenshot.screenshotWindow() }
		function monitor(): void { screenshot.screenshotMonitor() }
		function region(): void  { screenshot.screenshotRegion() }
		function color(): void   { screenshot.colorPicker() }
	}

	// Pickers
	IpcHandler {
		target: "pick"
		function emoji(): void  { emojiPicker.active = !emojiPicker.active }
		function icon(): void   { nerdFontPicker.active = !nerdFontPicker.active }
		function notes(): void  { notesPicker.active = !notesPicker.active }
		function audio(): void  { audioSwitcher.active = !audioSwitcher.active }
		function mixer(): void  { audioMixer.active = !audioMixer.active }
		function apps(): void { appLauncher.active = !appLauncher.active }
		function dmenu(inputFile: string, outputFile: string, prompt: string): void {
			dmenu.open(inputFile, outputFile, prompt)
		}
	}

	// Screen Recorder IPC
	IpcHandler {
		target: "recorder"
		function toggleRecord(): void { screenRecorder.toggleRecord(false) }
		function toggleRecordArea(): void { screenRecorder.toggleRecord(true) }
		function toggleStream(): void { screenRecorder.toggleStream() }
		function toggleGif(): void { screenRecorder.toggleGif(false) }
		function toggleGifArea(): void { screenRecorder.toggleGif(true) }
		function actionPicker(): void { screenRecorder.showActionPicker() }
	}

	// Bar
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

				// Profile / media pill
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26
					Layout.preferredWidth: profileMediaLayout.implicitWidth + 12
					color: root.cal2
					radius: 13
					clip: true

					Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

					RowLayout {
						id: profileMediaLayout
						anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
						spacing: 8

						Item {
							Layout.preferredWidth: 22; Layout.preferredHeight: 22
							Layout.alignment: Qt.AlignVCenter
							Image { id: profileImg; anchors.fill: parent; source: "icon.png"; fillMode: Image.PreserveAspectCrop; visible: false }
							Rectangle { id: profileMask; anchors.fill: parent; radius: width/2; visible: false }
							OpacityMask { anchors.fill: parent; source: profileImg; maskSource: profileMask }
						}

						RowLayout {
							visible: media.showMedia; spacing: 8; Layout.alignment: Qt.AlignVCenter
							Rectangle { width: 1; height: 12; color: root.cal3 }
							Item {
								Layout.preferredWidth: 22; Layout.preferredHeight: 22
								Image { id: musicArt; anchors.fill: parent; source: media.displayArtUrl; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
								Rectangle { id: musicMask; anchors.fill: parent; radius: width/2; visible: false }
								OpacityMask {
									id: spinningArt; anchors.fill: parent; source: musicArt; maskSource: musicMask; visible: media.displayArtUrl !== ""
									RotationAnimation on rotation {
										id: spinAnim; loops: Animation.Infinite; from: spinningArt.rotation; to: spinningArt.rotation+360; duration: 5000; running: media.isPlaying
										onRunningChanged: { if (running) { from = spinningArt.rotation; to = spinningArt.rotation+360 } }
									}
								}
							}
							Text { text: media.icon; color: root.cal14; font.pixelSize: root.fontSize+2; font.family: root.fontFamily }
							Item {
								Layout.preferredWidth: Math.min(180, songTxt.implicitWidth); Layout.preferredHeight: songTxt.implicitHeight; clip: true
								Text {
									id: songTxt; x: 0; text: media.title; color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily
									onTextChanged: { songScrollAnim.stop(); songTxt.x = 0; if (songTxt.implicitWidth > 180) songScrollAnim.restart() }
									SequentialAnimation {
										id: songScrollAnim; loops: Animation.Infinite; running: songTxt.implicitWidth > 180 && media.isPlaying
										PauseAnimation { duration: 1000 }
										NumberAnimation { target: songTxt; property: "x"; from: 0; to: -(songTxt.implicitWidth-180); duration: Math.max(0, (songTxt.implicitWidth-180)*30) }
										PauseAnimation { duration: 1000 }
										NumberAnimation { target: songTxt; property: "x"; from: -(songTxt.implicitWidth-180); to: 0; duration: Math.max(0, (songTxt.implicitWidth-180)*30) }
									}
								}
							}
						}
					}

					MouseArea {
						anchors.fill: parent; cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
						hoverEnabled: true
						onClicked: (m) => {
							if (media.showMedia) {
								if (m.button === Qt.LeftButton) media.playPause()
								else if (m.button === Qt.RightButton) { appLauncher.active = true }
								else if (m.button === Qt.MiddleButton) root.powerMenuVisible = true
							} else {
								if (m.button === Qt.LeftButton) { appLauncher.active = true }
								else root.powerMenuVisible = true
							}
						}
						onWheel: (wheel) => { if (media.showMedia) { if (wheel.angleDelta.y > 0) media.next(); else media.previous() } }
					}
				}

				// Layout indicator
				Rectangle {
					Layout.preferredHeight: 26; Layout.preferredWidth: layoutText.implicitWidth + 24; color: root.cal2; radius: 13
					Text { id: layoutText; anchors.centerIn: parent; text: root.currentLayout; color: root.cal7; font.pixelSize: root.fontSize-2; font.family: root.fontFamily; font.bold: true }
				}

				// Window title
				Rectangle {
					id: windowTitlePill
					Layout.preferredHeight: 26; Layout.fillWidth: true; Layout.minimumWidth: 100; color: root.cal2; radius: 13; clip: true
					RowLayout {
						anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 10
						Text { text: localActiveWindow === "Desktop" ? "󰇄" : "󱂬"; color: root.cal10; font.pixelSize: root.fontSize+2; font.family: root.fontFamily }
						Text { Layout.fillWidth: true; text: localActiveWindow; color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
					}
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						hoverEnabled: true
						onEntered: windowTitlePill.color = root.cal3
						onExited: windowTitlePill.color = root.cal2
						onClicked: audioMixer.active = true
					}
				}

				// Recording / Screencast pill
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26
					Layout.preferredWidth: recordRow.implicitWidth + 20
					color: root.cal2
					radius: 13

					Row {
						id: recordRow
						anchors.centerIn: parent
						spacing: 0
						property bool pinned: false
						property bool hovered: false
						readonly property bool expanded: pinned || hovered
						property bool active: screenRecorder.recording || screenRecorder.streaming || screenRecorder.recordingGif

						// Icon (always visible)
						Text {
							text: recordRow.active ? (screenRecorder.recording || screenRecorder.recordingGif ? "󰑊" : "󰐊") : ""
							color: recordRow.active ? root.cal10 : root.cal10
							font.pixelSize: root.fontSize + 2
							font.family: root.fontFamily
							anchors.verticalCenter: parent.verticalCenter
						}

						// Expanding text (hidden by default)
						Item {
							width: recordRow.expanded ? recTxt.implicitWidth + 8 : 0
							height: 20
							clip: true
							anchors.verticalCenter: parent.verticalCenter
							Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

							Text {
								id: recTxt
								anchors.left: parent.left
								anchors.leftMargin: 6
								anchors.verticalCenter: parent.verticalCenter
								text: recordRow.active ? (screenRecorder.recording ? "REC" : (screenRecorder.recordingGif ? "GIF" : "LIVE")) : "Idle"
								color: recordRow.active ? root.cal10 : root.cal10
								font.pixelSize: root.fontSize
								font.family: root.fontFamily
								font.bold: true
								opacity: parent.width > 5 ? 1 : 0
								Behavior on opacity { NumberAnimation { duration: 200 } }
							}
						}
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
						hoverEnabled: true

						onEntered: recordRow.hovered = true
						onExited: recordRow.hovered = false

						onClicked: (m) => {
							if (m.button === Qt.MiddleButton) {
								// Toggle permanent pin state
								recordRow.pinned = !recordRow.pinned
							} else if (m.button === Qt.LeftButton) {
								// Show action picker (start/stop selection)
								screenRecorder.showActionPicker()
							} else if (m.button === Qt.RightButton) {
								// Stop all active sessions, or show picker if none
								if (screenRecorder.recording || screenRecorder.streaming || screenRecorder.recordingGif) {
									if (screenRecorder.recording) screenRecorder.stopRecord()
									if (screenRecorder.streaming) screenRecorder.stopStream()
									if (screenRecorder.recordingGif) screenRecorder.stopGif()
								} else {
									screenRecorder.showActionPicker()
								}
							}
						}
					}
				}

				// Weather pill
				Rectangle {
					visible: isPrimary
					Layout.preferredHeight: 26
					Layout.preferredWidth: weatherRow.implicitWidth + 20
					color: root.cal2
					radius: 13

					Row {
						id: weatherRow
						anchors.centerIn: parent
						spacing: 0
						property bool pinned: false
						property bool hovered: false
						readonly property bool expanded: pinned || hovered

						// Icon (always visible)
						Text {
							text: root.weatherIcon
							color: root.cal7
							font.pixelSize: root.fontSize + 2
							font.family: root.fontFamily
							anchors.verticalCenter: parent.verticalCenter
						}

						// Expanding text (hidden by default)
						Item {
							width: weatherRow.expanded ? weatherTxt.implicitWidth + 8 : 0
							height: 20
							clip: true
							anchors.verticalCenter: parent.verticalCenter
							Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

							Text {
								id: weatherTxt
								anchors.left: parent.left
								anchors.leftMargin: 6
								anchors.verticalCenter: parent.verticalCenter
								text: root.weatherText
								color: root.cal7
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
						onEntered: weatherRow.hovered = true
						onExited: weatherRow.hovered = false
						onClicked: (m) => {
							if (m.button === Qt.MiddleButton) {
								weatherRow.pinned = !weatherRow.pinned
							} else if (m.button === Qt.LeftButton) {
								weather.active = !weather.active
							}
						}
					}
				}

				// Stats
				Rectangle {
					visible: isPrimary; Layout.preferredHeight: 26; Layout.preferredWidth: statsRow.implicitWidth + 30; color: root.cal2; radius: 13
					RowLayout {
						id: statsRow; anchors.centerIn: parent; spacing: 12

						// Kernel
						Item {
							Layout.preferredHeight: 20
							Layout.preferredWidth: kernelRow.implicitWidth

							Row {
								id: kernelRow
								anchors.fill: parent          // make the Row occupy the full pill height
								spacing: 0
								property bool pinned: false
								property bool hovered: false
								readonly property bool expanded: pinned || hovered

								Text {
									text: root.kernelIcon
									color: root.cal9
									font.pixelSize: root.fontSize + 2
									font.family: root.fontFamily
									anchors.verticalCenter: parent.verticalCenter   // center within the Row
								}

								Item {
									width: parent.expanded ? kernelTxt.implicitWidth + 8 : 0
									height: 20
									clip: true
									anchors.verticalCenter: parent.verticalCenter
									Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

									Text {
										id: kernelTxt
										anchors.left: parent.left
										anchors.leftMargin: 6
										anchors.verticalCenter: parent.verticalCenter
										text: root.kernelVersion
										color: root.cal9
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
								acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
								hoverEnabled: true
								onEntered: kernelRow.hovered = true
								onExited: kernelRow.hovered = false
								onClicked: (m) => {
									if (m.button === Qt.MiddleButton) {
										kernelRow.pinned = !kernelRow.pinned
									} else if (m.button === Qt.LeftButton || m.button === Qt.RightButton) {
										root.sysMonVisible = !root.sysMonVisible
									}
								}
							}
						}

						// CPU
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: cpuRow.implicitWidth
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
							Layout.preferredHeight: 20; Layout.preferredWidth: gpuRow.implicitWidth
							Row {
								id: gpuRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.gpuIcon; color: root.cal9; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? gpuTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: gpuTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.gpuText; color: root.cal9; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: gpuRow.hovered = true; onExited: gpuRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) gpuRow.pinned = !gpuRow.pinned; } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3 }

						// Memory
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: memRow.implicitWidth
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
							Layout.preferredHeight: 20; Layout.preferredWidth: diskRow.implicitWidth
							Row {
								id: diskRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.diskIcon; color: root.cal7; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? diskTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: diskTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.diskText; color: root.cal7; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: diskRow.hovered = true; onExited: diskRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) diskRow.pinned = !diskRow.pinned; } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3; visible: bright.available || battery.show }

						// Brightness
						Item {
							visible: bright.available
							Layout.preferredHeight: 20; Layout.preferredWidth: brightRow.implicitWidth
							Row {
								id: brightRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: bright.icon; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? brightTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: brightTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: bright.text; color: root.cal10; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: brightRow.hovered = true; onExited: brightRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) brightRow.pinned = !brightRow.pinned } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3; visible: bright.available && battery.show }
						// Battery
						Item {
							visible: battery.show; Layout.preferredHeight: 20; Layout.preferredWidth: batRow.implicitWidth
							Row {
								id: batRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: battery.icon; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? batTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: batTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: battery.text; color: root.cal10; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: batRow.hovered = true; onExited: batRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) batRow.pinned = !batRow.pinned } }
						}

						Rectangle { width: 1; height: 12; color: root.cal3; visible: (root.showEth || root.showWifi || root.showTail) }

						// Ethernet
						Item {
							visible: root.showEth
							Layout.preferredHeight: 20; Layout.preferredWidth: ethRow.implicitWidth
							Row {
								id: ethRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.ethIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? ethTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: ethTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.ethText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: ethRow.hovered = true; onExited: ethRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) ethRow.pinned = !ethRow.pinned; else if (m.button === Qt.RightButton) { shellCmd.command = ["nm-connection-editor"]; shellCmd.running = false; shellCmd.running = true } } }
						}

						// WiFi
						Item {
							visible: root.showWifi
							Layout.preferredHeight: 20; Layout.preferredWidth: wifiRow.implicitWidth
							Row {
								id: wifiRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.wifiIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? wifiTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: wifiTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.wifiText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: wifiRow.hovered = true; onExited: wifiRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) wifiRow.pinned = !wifiRow.pinned; else if (m.button === Qt.LeftButton) { wifiManager.active = !wifiManager.active } else if (m.button === Qt.RightButton) { shellCmd.command = ["nm-connection-editor"]; shellCmd.running = false; shellCmd.running = true } } }
						}

						// Tailscale
						Item {
							visible: root.showTail
							Layout.preferredHeight: 20; Layout.preferredWidth: tailRow.implicitWidth
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
							Layout.preferredHeight: 20; Layout.preferredWidth: micRow.implicitWidth
							Row {
								id: micRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: audio.micIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? micTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: micTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: audio.micText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: micRow.hovered = true; onExited: micRow.hovered = false; onWheel: (wheel) => { if (wheel.angleDelta.y > 0) audio.micUp(); else audio.micDown() }; onClicked: (m) => { if(m.button === Qt.MiddleButton) micRow.pinned = !micRow.pinned; else if (m.button === Qt.LeftButton) { audio.micToggle() } else if (m.button === Qt.RightButton) { audioSwitcher.active = true } } }
						}

						// Volume
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: volRow.implicitWidth
							Row {
								id: volRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: audio.volIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? volTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: volTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: audio.volText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: volRow.hovered = true; onExited: volRow.hovered = false; onWheel: (wheel) => { if (wheel.angleDelta.y > 0) audio.volUp(); else audio.volDown() }; onClicked: (m) => { if(m.button === Qt.MiddleButton) volRow.pinned = !volRow.pinned; else if (m.button === Qt.LeftButton) { audio.volToggle() } else if (m.button === Qt.RightButton) { audioSwitcher.active = true } } }
						}
					}
				}

				// Clock
				Rectangle {
					visible: isPrimary; Layout.preferredHeight: 26; Layout.preferredWidth: clockText.implicitWidth + 30; color: root.cal2; radius: 13
					Text {
						id: clockText; anchors.centerIn: parent
						property var dateTime: new Date()
						text: Qt.formatDateTime(dateTime, "󰥔  hh:mm AP |   dddd MMMM dd yyyy")
						color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
						Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.dateTime = new Date() }
					}
				}

				// Notification center toggle
				Rectangle {
					visible: isPrimary; Layout.preferredHeight: 26; Layout.preferredWidth: 26; radius: 13
					color: root.notifCenterVisible ? root.cal3 : root.cal2
					Text {
						anchors.centerIn: parent
						text: notifs.dndEnabled ? "\uf1f6" : (notifs.popups.values.length > 0 ? "\uf0f3" : "\uf0a2")
						color: notifs.dndEnabled ? root.cal14 : (root.notifCenterVisible ? root.cal7 : root.cal6)
						font.pixelSize: root.fontSize + 2; font.family: root.fontFamily
					}
					Rectangle {
						visible: !notifs.dndEnabled && notifs.popups.values.length > 0; width: 8; height: 8; radius: 4
						color: root.cal11; border.width: 1; border.color: root.cal0
						anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -1; anchors.rightMargin: -1
					}
					MouseArea {
						anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
						onClicked: (m) => { if (m.button === Qt.LeftButton) root.notifCenterVisible = !root.notifCenterVisible; else if (m.button === Qt.RightButton) notifs.dismissAll() }
					}
				}
			}
		}
	}

	// OSD popup
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
			width: 260; height: 44; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
			color: root.osdBgColor; radius: 10; border.width: 2; border.color: root.osdAccent
			RowLayout {
				anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
				Text { text: root.osdLabel; color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true }
				Rectangle {
					Layout.fillWidth: true; Layout.preferredHeight: 10; radius: 5; color: root.cal3; clip: true
					Rectangle {
						anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; radius: 5
						width: root.osdLevel >= 0 ? parent.width * Math.min(root.osdLevel,100)/100 : 0
						color: root.osdAccent
						Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
					}
				}
			}
		}
	}

	// Media OSD popup
	PanelWindow {
		id: mosdWindow
		screen: Quickshell.screens[0]
		visible: root.mosdVisible
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay

		anchors { left: true; right: true; bottom: true }
		margins.bottom: 110
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

				// Album art
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

					Rectangle {
						id: mosdArtMask
						anchors.fill: parent
						radius: 8
						visible: false
					}

					OpacityMask {
						anchors.fill: parent
						source: mosdArt
						maskSource: mosdArtMask
						visible: media.displayArtUrl !== ""
					}
				}

				// Text and progress
				ColumnLayout {
					Layout.fillWidth: true
					Layout.fillHeight: true
					spacing: 4

					RowLayout {
						spacing: 6
						Layout.fillWidth: true

						Text {
							text: root.mosdSourceIcon
							color: root.cal14
							font.pixelSize: root.fontSize
							font.family: root.fontFamily
						}

						Text {
							text: media.icon
							color: root.cal14
							font.pixelSize: root.fontSize
							font.family: root.fontFamily
						}

						Text {
							Layout.fillWidth: true
							text: media.title
							color: root.cal6
							font.pixelSize: root.fontSize + 1
							font.family: root.fontFamily
							font.bold: true
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
						color: root.cal15
						font.pixelSize: root.fontSize - 1
						font.family: root.fontFamily
						elide: Text.ElideRight
					}

					Item { Layout.fillHeight: true }

					Text {
						Layout.alignment: Qt.AlignRight
						visible: media.progressTime !== ""
						text: media.progressTime
						color: root.cal15
						font.pixelSize: root.fontSize - 2
						font.family: root.fontFamily
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

	// Notification popups
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
					Layout.preferredHeight: notifContent.implicitHeight + 16
					radius: 10
					color: root.osdBgColor
					border.width: 2
					border.color: root.notifBorder(modelData.urgency)
					clip: true

					readonly property real progressValue: {
						const h = notifCard.modelData.hints
						return (h && h.value !== undefined) ? Math.min(Math.max(h.value, 0), 100) : 0
					}

					Timer {
						running: notifCard.modelData.expireTimeout > 0
						interval: notifCard.modelData.expireTimeout * 1000
						onTriggered: notifCard.modelData.expire()
					}

					MouseArea {
						anchors.fill: parent
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
						cursorShape: Qt.PointingHandCursor
						onClicked: mouse => {
							if (mouse.button === Qt.LeftButton) notifCard.modelData.dismiss()
							else if (mouse.button === Qt.RightButton) notifs.dismissAll()
							else if (mouse.button === Qt.MiddleButton) {
								notifs.invokeDefaultAction(notifCard.modelData)
								notifCard.modelData.dismiss()
							}
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

						// Icon / image
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

						// Text content
						ColumnLayout {
							Layout.fillWidth: true
							spacing: 3

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

							// Progress bar (if present)
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
									width: parent.width * notifCard.progressValue / 100
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

	// Notification center
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
			radius: 13
			color: root.cal0
			border.width: 2
			border.color: root.cal3

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 8
				spacing: 8

				RowLayout {
					Layout.fillWidth: true

					Rectangle {
						Layout.preferredHeight: 26
						Layout.preferredWidth: notifHeaderText.implicitWidth + 24
						radius: 13
						color: root.cal2

						Text {
							id: notifHeaderText
							anchors.centerIn: parent
							text: notifs.popups.values.length > 0 ? "\uf0f3 Notifications" : "\uf0a2 Notifications"
							color: root.cal6
							font.family: root.fontFamily
							font.pixelSize: root.fontSize
							font.bold: true
						}
					}

					Item { Layout.fillWidth: true }

					Rectangle {
						id: dndBtn
						Layout.preferredHeight: 26
						Layout.preferredWidth: dndText.implicitWidth + 24
						radius: 13
						color: notifs.dndEnabled ? root.cal14 : root.cal2
						border.width: 1
						border.color: root.cal3

						Text {
							id: dndText
							anchors.centerIn: parent
							text: "\uf1f6  DND"
							color: notifs.dndEnabled ? root.cal14 : root.cal6
							font.family: root.fontFamily
							font.pixelSize: root.fontSize
							font.bold: true
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							hoverEnabled: true
							onClicked: notifs.dndEnabled = !notifs.dndEnabled
							onEntered: {
								parent.color = root.cal3
								parent.border.color = root.cal14
							}
							onExited: {
								parent.color = root.cal2
								parent.border.color = root.cal3
							}
						}
					}

					Rectangle {
						Layout.preferredHeight: 26
						Layout.preferredWidth: clearText.implicitWidth + 20
						radius: 13
						color: root.cal2

						Text {
							id: clearText
							anchors.centerIn: parent
							text: "Clear"
							color: root.cal8
							font.family: root.fontFamily
							font.pixelSize: root.fontSize
							font.bold: true
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							hoverEnabled: true
							onClicked: {
								// "Clear" previously only wiped history, leaving any
								// still-active popup on screen (and the bell icon
								// still showing its "unread" state) even though the
								// button reads as a clear-everything action.
								notifs.dismissAll()
								notifs.clearHistory()
							}
							onEntered: {
								parent.color = root.cal3
								parent.border.color = root.cal14
							}
							onExited: {
								parent.color = root.cal2
								parent.border.color = root.cal3
							}
						}
					}
				}

				Rectangle {
					visible: media.showMedia
					Layout.fillWidth: true
					Layout.preferredHeight: 108
					radius: 13
					color: root.cal2
					clip: true

					RowLayout {
						anchors.fill: parent
						anchors.margins: 8
						spacing: 10

						Item {
							Layout.preferredWidth: 64
							Layout.preferredHeight: 64
							Layout.alignment: Qt.AlignVCenter

							Rectangle {
								anchors.fill: parent
								radius: 8
								color: root.cal1
								visible: media.displayArtUrl === ""
							}

							Image {
								id: ncArt
								anchors.fill: parent
								source: media.displayArtUrl
								fillMode: Image.PreserveAspectCrop
								visible: false
								asynchronous: true
							}

							Rectangle {
								id: ncArtMask
								anchors.fill: parent
								radius: 8
								visible: false
							}

							OpacityMask {
								anchors.fill: parent
								source: ncArt
								maskSource: ncArtMask
								visible: media.displayArtUrl !== ""
							}
						}

						ColumnLayout {
							Layout.fillWidth: true
							spacing: 2

							RowLayout {
								spacing: 6

								Text {
									text: root.mosdSourceIcon
									color: root.cal14
									font.family: root.fontFamily
									font.pixelSize: root.fontSize
								}

								Text {
									text: media.icon
									color: root.cal14
									font.family: root.fontFamily
									font.pixelSize: root.fontSize
								}

								Text {
									Layout.fillWidth: true
									text: media.title
									color: root.cal6
									font.family: root.fontFamily
									font.pixelSize: root.fontSize
									font.bold: true
									elide: Text.ElideRight
								}
							}

							Text {
								Layout.fillWidth: true
								visible: media.artist !== "" || media.album !== ""
								text: {
									const hasArtist = media.artist !== "";
									const hasAlbum = media.album !== "";
									if (hasArtist && hasAlbum) return media.artist + " — " + media.album;
									if (hasArtist) return media.artist;
									return "";
								}
								color: root.cal15
								font.family: root.fontFamily
								font.pixelSize: root.fontSize - 1
								elide: Text.ElideRight
							}

							RowLayout {
								Layout.fillWidth: true
								Layout.topMargin: 4
								spacing: 12

								Item { Layout.fillWidth: true }

								Text {
									text: "󰒫"
									color: root.cal14
									font.family: root.fontFamily
									font.pixelSize: root.fontSize + 8
									MouseArea {
										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										onClicked: media.seekBackward()
									}
								}

								Text {
									text: "󰒮"
									color: root.cal14
									font.family: root.fontFamily
									font.pixelSize: root.fontSize + 8
									MouseArea {
										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										onClicked: media.previous()
									}
								}

								Text {
									text: media.icon
									color: root.cal14
									font.family: root.fontFamily
									font.pixelSize: root.fontSize + 8
									MouseArea {
										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										onClicked: media.playPause()
									}
								}

								Text {
									text: "󰒭"
									color: root.cal14
									font.family: root.fontFamily
									font.pixelSize: root.fontSize + 8
									MouseArea {
										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										onClicked: media.next()
									}
								}

								Text {
									text: "󰒬"
									color: root.cal14
									font.family: root.fontFamily
									font.pixelSize: root.fontSize + 8
									MouseArea {
										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										onClicked: media.seekForward()
									}
								}

								Item { Layout.fillWidth: true }
							}

							Text {
								Layout.alignment: Qt.AlignRight
								visible: media.progressTime !== ""
								text: media.progressTime
								color: root.cal15
								font.family: root.fontFamily
								font.pixelSize: root.fontSize - 2
							}

							Rectangle {
								Layout.fillWidth: true
								Layout.preferredHeight: 4
								radius: 2
								color: root.cal3
								clip: true

								Rectangle {
									anchors.left: parent.left
									anchors.top: parent.top
									anchors.bottom: parent.bottom
									radius: 2
									width: media.progressPct >= 0 ? parent.width * Math.min(media.progressPct, 100) / 100 : 0
									color: root.cal14
									Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.Linear } }
								}
							}
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
						required property int index
						width: ListView.view.width
						height: histRow.implicitHeight + 12
						radius: 13
						color: root.cal2

						RowLayout {
							id: histRow
							anchors.fill: parent
							anchors.margins: 8
							spacing: 8

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

								Text {
									Layout.fillWidth: true
									text: modelData.summary
									textFormat: Text.StyledText
									color: root.cal6
									font.family: root.fontFamily
									font.pixelSize: root.fontSize - 1
									font.bold: true
									horizontalAlignment: Text.AlignHCenter        // centered
									wrapMode: Text.Wrap
									elide: Text.ElideRight
									maximumLineCount: 2
								}

								Text {
									Layout.fillWidth: true
									visible: modelData.body !== ""
									text: modelData.body
									textFormat: Text.StyledText
									color: root.cal15
									font.family: root.fontFamily
									font.pixelSize: root.fontSize - 2
									horizontalAlignment: Text.AlignHCenter        // centered
									wrapMode: Text.Wrap
									maximumLineCount: 4
									elide: Text.ElideRight
								}
							}

							// Delete button (✕)
							Text {
								text: "✕"
								color: root.cal8
								font.family: root.fontFamily
								font.pixelSize: root.fontSize + 2
								Layout.alignment: Qt.AlignVCenter

								MouseArea {
									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									onClicked: notifs.removeHistory(index)
								}
							}
						}

						// Background click area (behind the RowLayout)
						MouseArea {
							anchors.fill: parent
							z: -1
							cursorShape: Qt.PointingHandCursor
							acceptedButtons: Qt.LeftButton
							onClicked: notifs.removeHistory(index)
						}
					}
				}
			}
		}
	}

	// Power menu overlay (single primary monitor, blurred background)
	PanelWindow {
		id: powerMenuWindow
		screen: Quickshell.screens[0]
		visible: root.powerMenuVisible
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay
		anchors { top: true; bottom: true; left: true; right: true }

		property string bgUrl: ""
		property real _lastCaptureTime: 0

		Connections {
			target: screenshot
			function onBackgroundCaptured(filePath) { powerMenuWindow.bgUrl = "file://" + filePath }
		}
		onVisibleChanged: {
			// Previously this re-ran hyprctl+grim on every single open. It's
			// only used as a blurred backdrop, so reusing a capture that's
			// less than a minute old is visually indistinguishable and
			// avoids spawning two processes every time someone opens the
			// power menu.
			if (visible) {
				const now = Date.now()
				if (powerMenuWindow.bgUrl === "" || (now - powerMenuWindow._lastCaptureTime) > 60000) {
					screenshot.captureFullForBackground()
					powerMenuWindow._lastCaptureTime = now
				}
			} else {
				powerMenuWindow.pendingConfirm = ""
			}
		}

		Rectangle {
			anchors.fill: parent; color: "black"
			Image {
				id: powerBgImage; anchors.fill: parent; source: powerMenuWindow.bgUrl
				fillMode: Image.PreserveAspectCrop; visible: powerMenuWindow.bgUrl !== ""; asynchronous: true
			}
			FastBlur { anchors.fill: powerBgImage; source: powerBgImage; radius: 64; visible: powerBgImage.visible }
			Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.6) }
		}

		MouseArea { anchors.fill: parent; z: -1; onClicked: { root.powerMenuVisible = false; powerMenuWindow.pendingConfirm = "" } }

		// Reboot/shutdown are destructive enough (unlike lock/suspend/
		// hibernate/logout, which are quick to recover from) that an
		// accidental click deserves a confirmation step first.
		property string pendingConfirm: ""   // "" | "Reboot" | "Shutdown"

		ColumnLayout {
			anchors.centerIn: parent; spacing: 20; width: 420; z: 1
			visible: powerMenuWindow.pendingConfirm === ""

			Text {
				text: "Power Menu"; color: root.cal6; font.family: root.fontFamily
				font.pixelSize: root.fontSize * 2; font.bold: true
				Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 10
			}
			RowLayout {
				Layout.fillWidth: true; spacing: 16
				PowerButton { icon: "󰍁"; label: "Lock"; fontSize: root.fontSize+6; Layout.preferredHeight:100; onClicked: { powerController.lock(); root.powerMenuVisible = false } }
				PowerButton { icon: "󰤄"; label: "Suspend"; fontSize: root.fontSize+6; Layout.preferredHeight:100; onClicked: { powerController.suspend(); root.powerMenuVisible = false } }
			}
			RowLayout {
				Layout.fillWidth: true; spacing: 16
				PowerButton { icon: "󰒲"; label: "Hibernate"; fontSize: root.fontSize+6; Layout.preferredHeight:100; onClicked: { powerController.hibernate(); root.powerMenuVisible = false } }
				PowerButton { icon: "󰗽"; label: "Logout"; fontSize: root.fontSize+6; Layout.preferredHeight:100; onClicked: { powerController.logout(); root.powerMenuVisible = false } }
			}
			RowLayout {
				Layout.fillWidth: true; spacing: 16
				PowerButton { icon: "󰜉"; label: "Reboot"; fontSize: root.fontSize+6; Layout.preferredHeight:100; onClicked: powerMenuWindow.pendingConfirm = "Reboot" }
				PowerButton { icon: "󰐥"; label: "Shutdown"; fontSize: root.fontSize+6; Layout.preferredHeight:100; onClicked: powerMenuWindow.pendingConfirm = "Shutdown" }
			}
			Rectangle {
				id: cancelButton; Layout.preferredWidth:200; Layout.preferredHeight:50; Layout.alignment: Qt.AlignHCenter; Layout.topMargin:20
				radius:25; color: root.cal2; border.width:2; border.color: root.cal3
				Text { anchors.centerIn: parent; text:"Cancel"; color: root.cal6; font.family: root.fontFamily; font.pixelSize: root.fontSize+4; font.bold:true }
				MouseArea {
					anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
					onEntered: { cancelButton.color = root.cal3; cancelButton.border.color = root.cal6 }
					onExited: { cancelButton.color = root.cal2; cancelButton.border.color = root.cal3 }
					onClicked: root.powerMenuVisible = false
				}
			}
		}

		// Confirmation sub-panel, shown in place of the button grid above
		// when pendingConfirm is set.
		ColumnLayout {
			anchors.centerIn: parent; spacing: 24; width: 380; z: 1
			visible: powerMenuWindow.pendingConfirm !== ""

			Text {
				text: powerMenuWindow.pendingConfirm + "?"
				color: root.cal6; font.family: root.fontFamily
				font.pixelSize: root.fontSize * 2; font.bold: true
				Layout.alignment: Qt.AlignHCenter
			}
			Text {
				text: "This will " + powerMenuWindow.pendingConfirm.toLowerCase() + " the system now."
				color: root.cal4; font.family: root.fontFamily
				font.pixelSize: root.fontSize
				Layout.alignment: Qt.AlignHCenter
			}
			RowLayout {
				Layout.fillWidth: true; spacing: 16; Layout.topMargin: 8

				Rectangle {
					Layout.fillWidth: true; Layout.preferredHeight: 56; radius: 16
					color: root.cal2; border.width: 2; border.color: root.cal3
					Text { anchors.centerIn: parent; text: "Cancel"; color: root.cal6; font.family: root.fontFamily; font.pixelSize: root.fontSize+2; font.bold: true }
					MouseArea {
						anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
						onEntered: { parent.color = root.cal3; parent.border.color = root.cal6 }
						onExited: { parent.color = root.cal2; parent.border.color = root.cal3 }
						onClicked: powerMenuWindow.pendingConfirm = ""
					}
				}
				Rectangle {
					Layout.fillWidth: true; Layout.preferredHeight: 56; radius: 16
					color: root.cal8; border.width: 2; border.color: root.cal11
					Text { anchors.centerIn: parent; text: "Confirm " + powerMenuWindow.pendingConfirm; color: root.cal0; font.family: root.fontFamily; font.pixelSize: root.fontSize+2; font.bold: true }
					MouseArea {
						anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
						onEntered: parent.border.color = root.cal6
						onExited: parent.border.color = root.cal11
						onClicked: {
							if (powerMenuWindow.pendingConfirm === "Reboot") powerController.reboot()
							else if (powerMenuWindow.pendingConfirm === "Shutdown") powerController.shutdown()
							powerMenuWindow.pendingConfirm = ""
							root.powerMenuVisible = false
						}
					}
				}
			}
		}
	}
}
