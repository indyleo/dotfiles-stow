import QtQuick
import Quickshell.Io

// Reads brightness from sysfs via FileView; writes via brightnessctl.
Item {
	id: root

	property string devicePath: ""
	property int current: 0
	property int max: 1
	readonly property int pct: max > 0 ? Math.round(current * 100 / max) : 0

	readonly property bool available: devicePath !== ""

	readonly property int step: 5

	readonly property string icon: pct >= 100 ? "󰛨"
		: pct >= 90 ? "󱩖"
		: pct >= 80 ? "󱩖"
		: pct >= 70 ? "󱩕"
		: pct >= 60 ? "󱩔"
		: pct >= 50 ? "󱩓"
		: pct >= 40 ? "󱩒"
		: pct >= 30 ? "󱩑"
		: pct >= 20 ? "󱩐"
		: pct >= 10 ? "󱩏"
		: "󱩎"
	readonly property string text: pct + "%"

	signal changed()
	onPctChanged: changed()

	Process {
		id: discoverProc
		command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				const name = text.trim()
				if (name !== "") root.devicePath = "/sys/class/backlight/" + name
			}
		}
	}

	FileView {
		id: maxFile
		path: root.devicePath !== "" ? root.devicePath + "/max_brightness" : ""
		onLoaded: root.max = parseInt(text(), 10) || 1
	}

	FileView {
		id: curFile
		path: root.devicePath !== "" ? root.devicePath + "/brightness" : ""
		watchChanges: true
		onFileChanged: reload()
		onLoaded: root.current = parseInt(text(), 10) || 0
	}

	Process { id: changeProc }

	function up(): int {
		const target = Math.min(100, pct + step)
		changeProc.command = ["brightnessctl", "set", step + "%+"]
		changeProc.running = false
		changeProc.running = true
		return target
	}
	function down(): int {
		const target = Math.max(0, pct - step)
		changeProc.command = ["brightnessctl", "set", step + "%-"]
		changeProc.running = false
		changeProc.running = true
		return target
	}
}
