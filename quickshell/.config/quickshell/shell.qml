import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
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

	property string brightIcon: "󰃠"
	property string brightText: "100%"
	property bool showBright: false

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

	property string volIcon: "󰕾"
	property string volText: "0%"
	property string micIcon: ""
	property string micText: "0%"

	// --- Screen/Media Data Properties ---
	property string sysMediaIcon: "" // Fallback icon if sysstats doesn't provide one
	property string sysMediaText: ""

	// --- Media Data Properties ---
	property string mediaIcon: "󰝚"
	property string mediaTitle: ""
	property string mediaArtist: ""
	property string mediaAlbum: ""
	property string mediaType: ""   // "song" | "browser", per mediactl's type field
	property string mediaArtUrl: ""
	property bool mediaIsPlaying: false
	property bool showMedia: false
	property int mediaProgress: -1        // 0-100, -1 if unavailable
	property string mediaProgressTime: "" // "M:SS / M:SS", empty if unavailable

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
		id: brightProc
		command: ["sysstats", "brightness"]
		stdout: SplitParser {
			onRead: data => {
				if (!data || data.trim() === "" || data.includes("N/A")) {
					root.showBright = false;
					return
				}
				root.showBright = true;
				root.parseSysstats(data, "brightIcon", "brightText")
			}
		}
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

	Process {
		id: volProc
		command: ["sysstats", "volume"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "volIcon", "volText") }
	}

	Process {
		id: micProc
		command: ["sysstats", "microphone"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "micIcon", "micText") }
	}

	// Media Process
	Process {
		id: sysMediaProc
		command: ["sysstats", "media"]
		stdout: SplitParser { onRead: data => root.parseSysstats(data, "sysMediaIcon", "sysMediaText") }
	}

	// Mediactl Process
	Process {
		id: mediaProc
		command: ["mediactl", "status"]
		stdout: SplitParser {
			onRead: data => {
				// 1. Properly check for idle/empty state
				if (!data || data.replace(/[\r\n]+$/, "") === "" || data.startsWith("idle")) {
					root.showMedia = false;
					return;
				}
				root.showMedia = true;

				// 2. Strip only trailing newlines so internal/trailing tabs stay intact
				let parts = data.replace(/[\r\n]+$/, "").split("\t");

				if (parts.length >= 5) {
					root.mediaType = (parts[0] || "").trim();
					root.mediaIsPlaying = (parts[2] === "Playing");
					root.mediaIcon = root.mediaIsPlaying ? "" : "";
					root.mediaTitle = parts[3] ? parts[3].trim() : "Unknown Title";
					root.mediaArtist = parts[4] ? parts[4].trim() : "Unknown Artist";

					// 3. Extract artwork URL. mediactl always emits all 9
					// tab-separated fields (empty values stay as empty
					// strings between tabs), so index 6 is always the
					// art_url slot -- it's never "shifted" by an omitted
					// album. Falling back to parts[5] (the album name) was
					// wrong: it turned plain album text into a bogus
					// "file://Album Name" URI whenever a track legitimately
					// had no art.
					let art = (parts[6] || "").trim();

					// 4. Format URI cleanly
					if (art.startsWith("http://") || art.startsWith("https://") || art.startsWith("file://")) {
						root.mediaArtUrl = art;
					} else if (art !== "") {
						root.mediaArtUrl = "file://" + art;
					} else {
						root.mediaArtUrl = "";
					}

					root.mediaAlbum = parts.length >= 6 ? (parts[5] || "").trim() : "";

					// 5. Progress percent (0-100, or -1 if unavailable) and
					// "M:SS / M:SS" text -- same fields mediaosd.c reads.
					root.mediaProgress = parts.length >= 8 && parts[7] !== "" ? parseInt(parts[7], 10) : -1;
					if (isNaN(root.mediaProgress)) root.mediaProgress = -1;
					root.mediaProgressTime = parts.length >= 9 ? (parts[8] || "").trim() : "";
				}
			}
		}
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
			brightProc.running = false; brightProc.running = true
			wifiProc.running = false; wifiProc.running = true
			ethProc.running = false; ethProc.running = true
			tailProc.running = false; tailProc.running = true
			batProc.running = false; batProc.running = true
			volProc.running = false; volProc.running = true
			micProc.running = false; micProc.running = true
			sysMediaProc.running = false; sysMediaProc.running = true
			mediaProc.running = false; mediaProc.running = true
		}
	}

	// --- OSD (On-Screen Display) -----------------------------------
	// Mirrors the dwm osd.c / osds[] setup: an external keybind fires an
	// IPC call, which runs a "change" command (wpctl/brightnessctl), then
	// re-reads the level and pops a bottom-center bar for OSD_TIMEOUT_MS.
	// Assumes wpctl (wireplumber) for volume/mic and brightnessctl for
	// brightness -- swap the command arrays below if you use something else.
	property bool osdVisible: false
	property string osdLabel: ""
	property int osdLevel: -1        // 0-100, or -1 for "no numeric level"
	property color osdAccent: cal14
	readonly property int osdTimeoutMs: 1200

	function osdParseLevel(text) {
		if (!text) return -1;
		const m = /(\d+)/.exec(text);
		return m ? Math.min(100, parseInt(m[1], 10)) : -1;
	}

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

	// "get" processes: re-read the level, refresh the matching bar pill,
	// and pop the OSD -- one process does both jobs (dwm's blockidx idea).
	Process {
		id: osdVolGetProc
		command: ["sysstats", "volume"]
		stdout: SplitParser { onRead: data => { root.parseSysstats(data, "volIcon", "volText"); root.osdShow("VOL", root.osdParseLevel(data), root.cal14) } }
	}
	Process {
		id: osdMicGetProc
		command: ["sysstats", "microphone"]
		stdout: SplitParser { onRead: data => { root.parseSysstats(data, "micIcon", "micText"); root.osdShow("MIC", root.osdParseLevel(data), root.cal14) } }
	}
	Process {
		id: osdBriGetProc
		command: ["sysstats", "brightness"]
		stdout: SplitParser {
			onRead: data => {
				if (!data || data.trim() === "" || data.includes("N/A")) return;
				root.showBright = true;
				root.parseSysstats(data, "brightIcon", "brightText");
				root.osdShow("BRI", root.osdParseLevel(data), root.cal10);
			}
		}
	}

	// "change" processes -- fired by the IpcHandler below, each kicks off
	// its matching get proc once the change has landed.
	Process { id: osdVolUpProc;     command: ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"]; onExited: { osdVolGetProc.running = false; osdVolGetProc.running = true } }
	Process { id: osdVolDownProc;   command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]; onExited: { osdVolGetProc.running = false; osdVolGetProc.running = true } }
	Process { id: osdVolToggleProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; onExited: { osdVolGetProc.running = false; osdVolGetProc.running = true } }

	Process { id: osdMicUpProc;     command: ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", "5%+"]; onExited: { osdMicGetProc.running = false; osdMicGetProc.running = true } }
	Process { id: osdMicDownProc;   command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "5%-"]; onExited: { osdMicGetProc.running = false; osdMicGetProc.running = true } }
	Process { id: osdMicToggleProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]; onExited: { osdMicGetProc.running = false; osdMicGetProc.running = true } }

	Process { id: osdBriUpProc;   command: ["brightnessctl", "set", "5%+"]; onExited: { osdBriGetProc.running = false; osdBriGetProc.running = true } }
	Process { id: osdBriDownProc; command: ["brightnessctl", "set", "5%-"]; onExited: { osdBriGetProc.running = false; osdBriGetProc.running = true } }

	// External trigger points -- bind these from hyprland.conf, e.g.:
	//   bindl = , XF86AudioRaiseVolume, exec, qs ipc call osd volUp
	// See osd.h's comment on osdtrigger() for the dwm-side equivalent.
	IpcHandler {
		target: "osd"
		function volUp(): void     { osdVolUpProc.running = false; osdVolUpProc.running = true }
		function volDown(): void   { osdVolDownProc.running = false; osdVolDownProc.running = true }
		function volToggle(): void { osdVolToggleProc.running = false; osdVolToggleProc.running = true }
		function micUp(): void     { osdMicUpProc.running = false; osdMicUpProc.running = true }
		function micDown(): void   { osdMicDownProc.running = false; osdMicDownProc.running = true }
		function micToggle(): void { osdMicToggleProc.running = false; osdMicToggleProc.running = true }
		function briUp(): void     { osdBriUpProc.running = false; osdBriUpProc.running = true }
		function briDown(): void   { osdBriDownProc.running = false; osdBriDownProc.running = true }
	}

	// --- Media OSD ("Now Playing" popup) -----------------------------
	// Mirrors mediaosd.c: album art + title/artist/album + a live
	// progress bar. Shows itself automatically whenever the track
	// changes (mediaProc already polls `mediactl status` every 2s), and
	// polls a bit faster while visible so the progress bar keeps moving,
	// same idea as mediaosd.c's MOSD_POLL_MS. Art isn't re-fetched
	// separately here (unlike the C version's curl/Imlib2 step) since
	// `mediactl status` already returns the art path/URL inline.
	readonly property int mosdTimeoutMs: 3500
	readonly property int mosdPollMs: 1000
	property bool mosdVisible: false
	readonly property string mosdSourceIcon: mediaType === "browser" ? "󰖟" : "󰝚"

	Timer {
		id: mosdHideTimer
		interval: root.mosdTimeoutMs
		onTriggered: root.mosdVisible = false
	}

	Timer {
		id: mosdPollTimer
		interval: root.mosdPollMs
		running: root.mosdVisible
		repeat: true
		onTriggered: { mediaProc.running = false; mediaProc.running = true }
	}

	function mosdShow() {
		root.mosdVisible = true;
		mosdHideTimer.restart();
	}

	// Auto-trigger on any real state change, matching medianotify's
	// real MPRIS push (which fires on track changes, play/pause, etc.,
	// not just title diffs) -- so resuming the same paused track pops
	// the OSD again too, same as mediaosd.c.
	onMediaTitleChanged: if (root.showMedia) root.mosdShow()
	onMediaArtistChanged: if (root.showMedia) root.mosdShow()
	onMediaIsPlayingChanged: if (root.showMedia) root.mosdShow()
	onShowMediaChanged: if (root.showMedia) root.mosdShow()

	// Manual/external trigger point, e.g. from a playerctl/MPRIS hook
	// script: qs ipc call mediaosd show
	IpcHandler {
		target: "mediaosd"
		function show(): void { mediaProc.running = false; mediaProc.running = true; root.mosdShow() }
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
							visible: root.showMedia
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
									source: root.mediaArtUrl
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
									visible: root.mediaArtUrl !== ""

									// 🌀 Spins the circular thumbnail when playing
									RotationAnimation on rotation {
										id: spinAnim
										loops: Animation.Infinite
										from: spinningArt.rotation  // resume from current angle, no jarring reset
										to: spinningArt.rotation + 360
										duration: 5000
										running: root.mediaIsPlaying

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
								text: root.mediaIcon
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
									text: root.mediaTitle !== "" ? root.mediaTitle : "Unknown Title"
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
										running: songTxt.implicitWidth > 180 && root.mediaIsPlaying

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
							if (root.showMedia) {
								if (m.button === Qt.LeftButton) {
									shellCmd.command = ["mediactl", "play-pause"]
								} else if (m.button === Qt.RightButton) {
									shellCmd.command = ["rofi", "-show", "drun"]
								} else if (m.button === Qt.MiddleButton) {
									shellCmd.command = ["sh", "-c", "power"]
								}
								shellCmd.running = false
								shellCmd.running = true

								mediaProc.running = false
								mediaProc.running = true
							} else {
								if (m.button === Qt.LeftButton) shellCmd.command = ["rofi", "-show", "drun"]
								else shellCmd.command = ["sh", "-c", "power"]
								shellCmd.running = false
								shellCmd.running = true
							}
						}

						onWheel: (wheel) => {
							if (root.showMedia) {
								if (wheel.angleDelta.y > 0) {
									shellCmd.command = ["mediactl", "next"]
								} else {
									shellCmd.command = ["mediactl", "previous"]
								}
								shellCmd.running = false
								shellCmd.running = true

								mediaProc.running = false
								mediaProc.running = true
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

						Rectangle { width: 1; height: 12; color: root.cal3; visible: root.showBright || root.showBat }

						// Brightness
						Item {
							visible: root.showBright
							Layout.preferredHeight: 20; Layout.preferredWidth: brightRow.width
							Row {
								id: brightRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.brightIcon; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? brightTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: brightTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.brightText; color: root.cal10; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: brightRow.hovered = true; onExited: brightRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) brightRow.pinned = !brightRow.pinned } }
						}

						// Battery
						Rectangle { width: 1; height: 12; color: root.cal3; visible: root.showBat && root.showBright }
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
								Text { text: root.micIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? micTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: micTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.micText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: micRow.hovered = true; onExited: micRow.hovered = false; onWheel: (wheel) => { if(wheel.angleDelta.y > 0) shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", "5%+"]; else shellCmd.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "5%-"]; shellCmd.running = false; shellCmd.running = true; micProc.running = false; micProc.running = true }; onClicked: (m) => { if(m.button === Qt.MiddleButton) micRow.pinned = !micRow.pinned; else if (m.button === Qt.LeftButton) { shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]; shellCmd.running = false; shellCmd.running = true; micProc.running = false; micProc.running = true } else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol", "-t", "4"]; shellCmd.running = false; shellCmd.running = true } } }
						}

						// Volume
						Item {
							Layout.preferredHeight: 20; Layout.preferredWidth: volRow.width
							Row {
								id: volRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
								Text { text: root.volIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
								Item { height: 20; width: parent.expanded ? volTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
								Text { id: volTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.volText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
							}
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true; onEntered: volRow.hovered = true; onExited: volRow.hovered = false; onWheel: (wheel) => { if(wheel.angleDelta.y > 0) shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"]; else shellCmd.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]; shellCmd.running = false; shellCmd.running = true; volProc.running = false; volProc.running = true }; onClicked: (m) => { if(m.button === Qt.MiddleButton) volRow.pinned = !volRow.pinned; else if (m.button === Qt.LeftButton) { shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; shellCmd.running = false; shellCmd.running = true; volProc.running = false; volProc.running = true } else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol", "-t", "3"]; shellCmd.running = false; shellCmd.running = true } } }
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
						visible: root.mediaArtUrl === ""
					}

					Image {
						id: mosdArt
						anchors.fill: parent
						source: root.mediaArtUrl
						fillMode: Image.PreserveAspectCrop
						visible: false
						asynchronous: true
					}
					Rectangle { id: mosdArtMask; anchors.fill: parent; radius: 8; visible: false }
					OpacityMask {
						anchors.fill: parent
						source: mosdArt
						maskSource: mosdArtMask
						visible: root.mediaArtUrl !== ""
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
						Text { text: root.mediaIcon; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily }
						Text {
							Layout.fillWidth: true
							text: root.mediaTitle !== "" ? root.mediaTitle : "Unknown Title"
							color: root.cal6; font.pixelSize: root.fontSize + 1; font.family: root.fontFamily; font.bold: true
							elide: Text.ElideRight
						}
					}

					Text {
						Layout.fillWidth: true
						text: {
							const hasArtist = root.mediaArtist !== "" && root.mediaArtist !== "Unknown Artist" && root.mediaArtist !== "Unknown";
							const hasAlbum = root.mediaAlbum !== "" && root.mediaAlbum !== "Unknown" && root.mediaAlbum !== "[Unknown Album]";
							if (hasArtist && hasAlbum) return root.mediaArtist + " — " + root.mediaAlbum;
							if (hasArtist) return root.mediaArtist;
							return "";
						}
						color: root.cal15; font.pixelSize: root.fontSize - 1; font.family: root.fontFamily
						elide: Text.ElideRight
					}

					Item { Layout.fillHeight: true }

					Text {
						Layout.alignment: Qt.AlignRight
						visible: root.mediaProgressTime !== ""
						text: root.mediaProgressTime
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
							width: root.mediaProgress >= 0 ? parent.width * Math.min(root.mediaProgress, 100) / 100 : 0
							color: root.cal14
							Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.Linear } }
						}
					}
				}
			}
		}
	}
}
