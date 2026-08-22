import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

PanelWindow {
	id: root

	    // Colors (same as shell)
    // Colors sourced from the central Theme singleton (Theme.qml)
    readonly property color cal0:  Theme.cal0
    readonly property color cal1:  Theme.cal1
    readonly property color cal2:  Theme.cal2
    readonly property color cal3:  Theme.cal3
    readonly property color cal4:  Theme.cal4
    readonly property color cal5:  Theme.cal5
    readonly property color cal6:  Theme.cal6
    readonly property color cal7:  Theme.cal7
    readonly property color cal8:  Theme.cal8
    readonly property color cal9:  Theme.cal9
    readonly property color cal10: Theme.cal10
    readonly property color cal11: Theme.cal11
    readonly property color cal12: Theme.cal12
    readonly property color cal13: Theme.cal13
    readonly property color cal14: Theme.cal14
    readonly property color cal15: Theme.cal15

	property bool active: false
	visible: active

	screen: Quickshell.screens[0]
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay

	anchors { top: true; bottom: true; left: true; right: true }

	property string bgUrl: ""
	property var screenshotProvider: null
	property var screenRecorder: null

	onActiveChanged: {
		if (root.active && root.screenshotProvider) {
			root.screenshotProvider.backgroundCaptured.connect(root.onBackgroundCaptured)
			root.screenshotProvider.captureFullForBackground()
		} else {
			if (root.screenshotProvider) {
				root.screenshotProvider.backgroundCaptured.disconnect(root.onBackgroundCaptured)
			}
		}
	}

	function onBackgroundCaptured(filePath) {
		root.bgUrl = "file://" + filePath
	}

	// --- System stats properties ---
	property string cpuIcon: ""
	property string cpuText: "0%"
	property string gpuIcon: "󰢮"
	property string gpuText: "0%"
	property string memIcon: ""
	property string memText: "0%"
	property string diskIcon: "󰋊"
	property string diskText: "0%"
	property string batIcon: "󰢜"
	property string batText: "100%"
	property bool batVisible: false
	property string ethIcon: "󰲜"
	property string ethText: "Disconnected"
	property bool ethVisible: false
	property string wifiIcon: "󰤮"
	property string wifiText: "Offline"
	property bool wifiVisible: true
	property string tailIcon: "󰈂"
	property string tailText: "Not connected"
	property bool tailVisible: false
	property string uptimeIcon: "󱎫"
	property string uptimeText: ""
	property string kernelIcon: ""
	property string kernelText: "..."
	property string mediaIcon: ""
	property string mediaText: "Idle"
	property string weatherIcon: "󰖐"
	property string weatherText: ""

	function parseSysstats(data, iconProp, textProp) {
		if (!data) return;
		let parts = data.trim().split(/\s+/);
		if (parts.length >= 1) root[iconProp] = parts[0];
		if (parts.length >= 2) root[textProp] = parts.slice(1).join(" ");
	}

	Process { id: cpuProc; command: ["sysstats", "cpu"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "cpuIcon", "cpuText") } }
	Process { id: gpuProc; command: ["sysstats", "gpu"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "gpuIcon", "gpuText") } }
	Process { id: memProc; command: ["sysstats", "mem"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "memIcon", "memText") } }
	Process { id: diskProc; command: ["sysstats", "disk"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "diskIcon", "diskText") } }

	// Updated battery process – hides when percentage is 0 or unparseable
	Process {
		id: batProc
		command: ["sysstats", "battery"]
		stdout: SplitParser {
			onRead: data => {
				if (!data || data.trim() === "" || data.includes("N/A") || data.startsWith("No")) {
					root.batVisible = false;
					return;
				}
				root.parseSysstats(data, "batIcon", "batText");
				// Extract numeric percentage from batText
				var match = root.batText.match(/(\d+(?:\.\d+)?)%/);
				if (match && match[1]) {
					var pct = parseFloat(match[1]);
					if (isFinite(pct) && pct > 0) {
						root.batVisible = true;
						return;
					}
				}
				root.batVisible = false;
			}
		}
	}

	Process { id: ethProc; command: ["sysstats", "ethernet"]; stdout: SplitParser { onRead: data => {
		if (!data) return;
		root.parseSysstats(data, "ethIcon", "ethText")
		root.ethVisible = data.includes("Connected") && !data.includes("Disconnected")
	} } }
	Process { id: wifiProc; command: ["sysstats", "wifi"]; stdout: SplitParser { onRead: data => {
		if (!data) return;
		root.parseSysstats(data, "wifiIcon", "wifiText")
		let isWifiConnected = !data.includes("Offline") && !data.includes("No tool") && !data.includes("Disconnected");
		root.wifiVisible = isWifiConnected || !root.ethVisible;
	} } }
	Process { id: tailProc; command: ["sysstats", "tail"]; stdout: SplitParser { onRead: data => {
		if (!data) return;
		root.parseSysstats(data, "tailIcon", "tailText")
		root.tailVisible = data.includes("Connected") && !data.includes("Not connected")
	} } }
	Process { id: uptimeProc; command: ["sysstats", "uptime"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "uptimeIcon", "uptimeText") } }
	Process { id: kernelProc; command: ["sysstats", "kernel"]; stdout: SplitParser { onRead: data => root.parseSysstats(data, "kernelIcon", "kernelText") } }
	Process { id: weatherProc; command: ["sysstats", "weather"]; stdout: SplitParser { onRead: data => {
		if (!data || data.trim() === "") {
			root.weatherIcon = "󰖐";
			root.weatherText = "";
			return;
		}
		root.parseSysstats(data, "weatherIcon", "weatherText");
	} } }

	// Refresh dynamic stats every 2 seconds
	Timer {
		interval: 2000
		running: root.active
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			cpuProc.running = false; cpuProc.running = true
			memProc.running = false; memProc.running = true
			diskProc.running = false; diskProc.running = true
			wifiProc.running = false; wifiProc.running = true
			ethProc.running = false; ethProc.running = true
			tailProc.running = false; tailProc.running = true
			batProc.running = false; batProc.running = true
			uptimeProc.running = false; uptimeProc.running = true
		}
	}

	// Refresh static stats every 60 seconds
	Timer {
		interval: 60000
		running: root.active
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			kernelProc.running = false; kernelProc.running = true
			gpuProc.running = false; gpuProc.running = true
			weatherProc.running = false; weatherProc.running = true
		}
	}

	// --- UI ---
	Rectangle {
		anchors.fill: parent
		color: "black"

		Image {
			id: bgImage
			anchors.fill: parent
			source: root.bgUrl
			fillMode: Image.PreserveAspectCrop
			visible: root.bgUrl !== ""
			asynchronous: true
		}

		FastBlur {
			anchors.fill: bgImage
			source: bgImage
			radius: 64
			visible: bgImage.visible
		}

		Rectangle {
			anchors.fill: parent
			color: Qt.rgba(0, 0, 0, 0.7)
		}
	}

	// Full‑screen click to close
	MouseArea {
		anchors.fill: parent
		z: 0
		onClicked: root.active = false
	}

	// Centered content
	ColumnLayout {
		anchors.centerIn: parent
		spacing: 20
		width: 600
		z: 1

		Text {
			text: "System Monitor"
			color: "#ebdbb2"
			font.family: "JetBrainsMono Nerd Font"
			font.pixelSize: 26
			font.bold: true
			Layout.alignment: Qt.AlignHCenter
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 16
			StatCard { icon: root.cpuIcon; text: root.cpuText; accent: "#d3869b" }
			StatCard { icon: root.gpuIcon; text: root.gpuText; accent: "#d3869b" }
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 16
			StatCard { icon: root.memIcon; text: root.memText; accent: "#83a598" }
			StatCard { icon: root.diskIcon; text: root.diskText; accent: "#83a598" }
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 16
			StatCard { visible: root.batVisible; icon: root.batIcon; text: root.batText; accent: "#fabd2f" }
			StatCard { icon: root.uptimeIcon; text: root.uptimeText; accent: "#d5c4a1" }
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 16
			StatCard { visible: root.ethVisible; icon: root.ethIcon; text: root.ethText; accent: "#b8bb26" }
			StatCard { visible: root.wifiVisible; icon: root.wifiIcon; text: root.wifiText; accent: "#b8bb26" }
			StatCard { visible: root.tailVisible; icon: root.tailIcon; text: root.tailText; accent: "#b8bb26" }
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 16
			StatCard {
				icon: root.screenRecorder ? (root.screenRecorder.recording ? "󰑊" : (root.screenRecorder.streaming ? "󰐊" : "")) : "󰝚"
				text: root.screenRecorder ? (root.screenRecorder.recording ? "REC" : (root.screenRecorder.streaming ? "LIVE" : "Idle")) : "Idle"
				accent: root.screenRecorder && (root.screenRecorder.recording || root.screenRecorder.streaming) ? root.cal10 : root.cal10
			}

			StatCard { visible: root.weatherText !== ""; icon: root.weatherIcon; text: root.weatherText; accent: "#83a598" }
		}

		RowLayout {
			Layout.fillWidth: true
			StatCard { icon: root.kernelIcon; text: root.kernelText; accent: "#d3869b" }
		}

		// Close button
		Rectangle {
			id: sysMonCloseBtn
			Layout.preferredWidth: 160
			Layout.preferredHeight: 40
			Layout.alignment: Qt.AlignHCenter
			radius: 20
			color: "#504945"
			border.width: 2
			border.color: "#7c6f64"

			Text {
				anchors.centerIn: parent
				text: "Close (Esc)"
				color: "#ebdbb2"
				font.family: "JetBrainsMono Nerd Font"
				font.pixelSize: 14
				font.bold: true
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				hoverEnabled: true
				onEntered: {
					sysMonCloseBtn.color = "#7c6f64"
					sysMonCloseBtn.border.color = "#ebdbb2"
				}
				onExited: {
					sysMonCloseBtn.color = "#504945"
					sysMonCloseBtn.border.color = "#7c6f64"
				}
				onClicked: root.active = false
			}
		}
	}

	// StatCard component
	component StatCard: Rectangle {
		property string icon: ""
		property string text: ""
		property color accent: "#ebdbb2"

		Layout.fillWidth: true
		Layout.preferredHeight: 50
		radius: 12
		color: "#504945"
		border.width: 1
		border.color: accent

		RowLayout {
			anchors.centerIn: parent
			spacing: 10

			Text {
				text: parent.parent.icon
				color: parent.parent.accent
				font.family: "JetBrainsMono Nerd Font"
				font.pixelSize: 18
			}
			Text {
				text: parent.parent.text
				color: "#ebdbb2"
				font.family: "JetBrainsMono Nerd Font"
				font.pixelSize: 14
				font.bold: true
			}
		}
	}
}