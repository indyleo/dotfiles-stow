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
				if (name !== "") {
					root.devicePath = "/sys/class/backlight/" + name
				} else {
					console.warn("[BrightnessController] No backlight device found in /sys/class/backlight - brightness control will not work")
				}
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

	// brightnessctl isn't installed on every system. Detect once at startup
	// and fall back to `light`, then finally a direct sysfs write (the same
	// udev/ACL rules that let brightnessctl run unprivileged generally allow
	// this too, since it targets the identical file).
	property string brightnessMethod: "brightnessctl"

	Process {
		id: detectBrightnessProc
		running: true
		command: ["sh", "-c",
			"command -v brightnessctl >/dev/null 2>&1 && echo brightnessctl || " +
			"{ command -v light >/dev/null 2>&1 && echo light || echo sysfs; }"
		]
		stdout: StdioCollector {
			onStreamFinished: {
				root.brightnessMethod = text.trim()
			}
		}
	}

	Process {
		id: changeProc
		stderr: StdioCollector {}
		onExited: (code, status) => {
			if (code !== 0) {
				console.warn("[BrightnessController] Failed to set brightness:", code, changeProc.stderr.text)
			}
		}
	}

	function applyBrightness(targetPct) {
		if (root.brightnessMethod === "brightnessctl") {
			changeProc.command = ["brightnessctl", "set", targetPct + "%"]
		} else if (root.brightnessMethod === "light") {
			changeProc.command = ["light", "-S", String(targetPct)]
		} else {
			// Last-resort fallback: write the raw value directly to sysfs.
			// FileView writes the file directly, so there's no shell
			// quoting involved even though device names could in theory
			// contain unusual characters.
			const newVal = Math.round(root.max * targetPct / 100)
			curFile.setText(String(newVal))
			return
		}
		changeProc.running = false
		changeProc.running = true
	}

	function up(): int {
		if (!available) return -1
		const target = Math.min(100, pct + step)
		applyBrightness(target)
		return target
	}
	function down(): int {
		if (!available) return -1
		const target = Math.max(0, pct - step)
		applyBrightness(target)
		return target
	}
}