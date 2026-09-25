import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// Wallpaper cycling, native to Quickshell - no awww/swww/feh involved.
// One background-layer PanelWindow per screen, each holding two stacked
// Images that crossfade between each other. wlr-layer-shell puts these
// windows below every normal window/panel, same as a dedicated wallpaper
// daemon would.
//
// Picking a random image from a directory is still done via `find`/`shuf`
// in a Process, since QML has no built-in recursive directory listing -
// everything after that (loading and displaying the image) is plain
// Quickshell/QML.
//
// Usage from shell.qml:
//   WallPaper {
//       id: wallPaper
//       wallpapersDir: "~/Pictures/Wallpapers/gruvbox"   // optional, default shown below
//       intervalSeconds: 900                              // optional, default shown below
//   }
// It starts cycling on its own once instantiated. wallPaper.random() is
// there for an out-of-cycle change (e.g. from a keybind/IPC), and just
// picks + applies immediately without touching the Timer's schedule.

Item {
	id: root

	property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
	property int intervalSeconds: 900
	property int transitionDurationMs: 1300

	property string lastWallpaper: ""

	function _monitorNames() {
		try {
			return (Hyprland.monitors || []).map(m => m.name)
		} catch (e) {
			root.log("WARN", `Could not read Hyprland.monitors: ${e}`)
			return []
		}
	}
	readonly property var monitorNames: root._monitorNames()

	// monitorName -> "file://..." - the PanelWindow delegates below bind
	// to this to know what to crossfade to.
	property var wallpaperPaths: ({})

	readonly property string findExpr:
		'find "$DIR" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \\) | shuf -n 1'

	// A leading "~" never gets shell-expanded once it's passed into
	// Process as a positional parameter rather than typed on a command
	// line - so every use of wallpapersDir goes through this first.
	function _expandHome(p) {
		const home = Quickshell.env("HOME") || ""
		return p.replace(/^~(?=$|\/)/, home)
	}

	Component.onCompleted: {
		root.log("INFO", `Wallpaper cycling starting on '${root.wallpapersDir}' (interval ${root.intervalSeconds}s)`)
		cycleTimer.interval = root.intervalSeconds * 1000
		root.random()   // set one immediately, then let the Timer take over
		cycleTimer.start()
	}

	// ---- logging -------------------------------------------------------
	function log(level, msg) {
		const line = `[wallpaper] [${level}] ${msg}`
		if (level === "ERROR" || level === "WARN") console.warn(line)
		else console.log(line)
	}

	// ---- random image picking (queued, one at a time) -------------------
	property var _pickQueue: []
	property bool _picking: false

	function _enqueuePick(monitor, baseDir) {
		root._pickQueue.push({ monitor: monitor, baseDir: baseDir })
		root._processPickQueue()
	}

	function _processPickQueue() {
		if (root._picking || root._pickQueue.length === 0) return
		root._picking = true
		const job = root._pickQueue.shift()
		pickProc.currentMonitor = job.monitor
		// Per-monitor subdir fallback: use <baseDir>/<monitor>/ if it
		// exists, else <baseDir> itself.
		pickProc.command = ["sh", "-c",
			`MON="$1"; BASE="$2"; DIR="$BASE/$MON"; [ -d "$DIR" ] || DIR="$BASE"; ${root.findExpr}`,
			"--", job.monitor, job.baseDir]
		pickProc.running = false
		pickProc.running = true
	}

	Process {
		id: pickProc
		property string currentMonitor: ""
		stdout: StdioCollector {
			onStreamFinished: {
				const img = text.trim()
				root._picking = false
				if (img.length > 0) {
					root._applyWallpaper(pickProc.currentMonitor, img)
				} else {
					root.log("ERROR", `No images found for monitor '${pickProc.currentMonitor}' under ${root.wallpapersDir}`)
				}
				root._processPickQueue()
			}
		}
	}

	// ---- applying a picked image -----------------------------------------
	// No external process here at all - just updates the map the
	// PanelWindow delegates below are bound to.
	function _applyWallpaper(monitor, img) {
		const url = "file://" + img
		const targets = monitor ? [monitor] : (root.monitorNames.length ? root.monitorNames : Quickshell.screens.map(s => s.name))
		let m = Object.assign({}, root.wallpaperPaths)
		for (const t of targets) m[t] = url
		root.wallpaperPaths = m

		root.lastWallpaper = img
		root.log("INFO", `[${monitor || "all monitors"}] Wallpaper set to ${img}`)
	}

	// ---- the one thing callable from outside -----------------------------
	function random() {
		const mons = root.monitorNames || []
		const dir = root._expandHome(root.wallpapersDir)
		if (mons.length === 0) {
			root.log("WARN", "No monitors detected via Hyprland, setting wallpaper globally.")
			root._enqueuePick("", dir)
			return
		}
		for (const m of mons) root._enqueuePick(m, dir)
	}

	Timer {
		id: cycleTimer
		repeat: true
		onTriggered: root.random()
	}

	// ---- one background-layer window per screen, crossfading between
	// two stacked Images -----------------------------------------------
	Variants {
		model: Quickshell.screens

		PanelWindow {
			id: wpWindow
			required property var modelData
			screen: modelData

			WlrLayershell.layer: WlrLayer.Background
			exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: "black"   // shows through until the first image loads

			property string targetSrc: root.wallpaperPaths[modelData.name] || ""
			property bool activeIsA: true   // which Image is currently visible

			onTargetSrcChanged: {
				if (targetSrc === "") return
				// Load into whichever Image is currently hidden; it swaps
				// in via the opacity Behavior once it's actually ready,
				// so there's no flash of a half-loaded frame.
				if (activeIsA) imgB.source = targetSrc
				else imgA.source = targetSrc
			}

			Image {
				id: imgA
				anchors.fill: parent
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				opacity: wpWindow.activeIsA ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: root.transitionDurationMs; easing.type: Easing.InOutQuad } }
				onStatusChanged: if (status === Image.Ready && !wpWindow.activeIsA) wpWindow.activeIsA = true
			}
			Image {
				id: imgB
				anchors.fill: parent
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				opacity: wpWindow.activeIsA ? 0 : 1
				Behavior on opacity { NumberAnimation { duration: root.transitionDurationMs; easing.type: Easing.InOutQuad } }
				onStatusChanged: if (status === Image.Ready && wpWindow.activeIsA) wpWindow.activeIsA = false
			}
		}
	}
}
