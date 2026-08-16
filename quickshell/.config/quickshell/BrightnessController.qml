import QtQuick
import Quickshell.Io

// There's no DBus/Pipewire-style service for backlight, so writing still
// goes through `brightnessctl` (sysfs brightness is usually only
// writable via a udev-granted group, which brightnessctl already
// handles). What this replaces is the *read* side: instead of spawning
// `sysstats bri_raw` / `sysstats brightness` on a timer or after every
// keypress, a FileView watches the sysfs brightness file directly with
// inotify (watchChanges: true) -- zero subprocesses to read the level,
// and it reacts to ANY change to the backlight, not just ones made
// through this shell.
//
// Usage in shell.qml:
//   BrightnessController { id: bright }
//   ... bright.pct / bright.up() / bright.down() ...
Item {
	id: root

	property string devicePath: ""
	property int current: 0
	property int max: 1
	readonly property int pct: max > 0 ? Math.round(current * 100 / max) : 0

	// True once a backlight device has actually been found -- mirrors
	// sysstats' "N/A" case (desktops with no backlight), which shell.qml
	// uses to hide the brightness pill entirely rather than show it.
	readonly property bool available: devicePath !== ""

	readonly property int step: 5 // percent, matches the old "5%+/-"

	// Tiers + codepoints verified byte-for-byte against sysstats'
	// bbrightness() (thanks for sharing that file) -- not guesses.
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

	// One-time device discovery at startup -- a single subprocess ever,
	// not something run per read or on a timer. brightnessctl itself
	// auto-detects the right device for writes; this just needs to know
	// which sysfs node to watch for reads.
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
		// max_brightness is fixed for the hardware's lifetime -- no need
		// to watch it, just read it once when the device is known.
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

	// Returns an optimistic post-change percent for instant OSD display.
	// The FileView above will correct `pct` for real a moment later
	// (inotify fires as soon as brightnessctl's write lands in sysfs --
	// milliseconds, not the old poll-driven lag), so this is a UI nicety,
	// not a source of truth.
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
