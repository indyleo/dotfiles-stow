import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

// Screen Recording & Streaming controller (Hyprland/Wayland only).
// Native replacement for the old rofi/dmenu-driven bash script: monitor
// selection now happens in a bar-styled overlay instead of shelling out,
// and record/stream are direct IPC-callable toggles.
Item {
	id: root

	// --- Public state (bind these to a bar indicator if you want one) ---
	property bool recording: false
	property bool streaming: false
	property bool recordingGif: false
	property string recordingOutput: ""
	property string streamingOutput: ""
	property string gifOutput: ""

	signal recordingStarted(string output)
	signal recordingStopped()
	signal streamingStarted(string output)
	signal streamingStopped()
	signal gifStarted(string output)
	signal gifStopped()
	signal actionFailed(string reason)

	property string fontFamily: "JetBrainsMono Nerd Font"
	property int fontSize: 13
	readonly property color cal0: "#282828"
	readonly property color cal2: "#504945"
	readonly property color cal3: "#7c6f64"
	readonly property color cal6: "#ebdbb2"
	readonly property color cal14: "#fe8019"
	readonly property color cal10: "#fabd2f"


	readonly property int fpsRecord: 60
	readonly property int fpsStream: 30
	readonly property int fpsGif: 15   // GIFs get large fast; a lower framerate keeps file size sane
	readonly property string streamServer: "ingest.global-contribute"

	readonly property string recPidFile: "/tmp/qs-recpid"
	readonly property string streamPidFile: "/tmp/qs-streampid"
	readonly property string gifPidFile: "/tmp/qs-gifpid"

	property bool hasNvidia: false
	property string videoCodec: "libx264"

	property var _pendingAction: null   // "record" | "stream"

	Component.onCompleted: {
		nvidiaCheckProc.running = true

		depCheckProc.command = ["sh", "-c", "for c in wf-recorder notify-send pactl hyprctl slurp; do command -v \"$c\" >/dev/null || echo \"$c\"; done"]
		depCheckProc.running = true
	}

	Process {
		id: nvidiaCheckProc
		command: ["sh", "-c", "[ -e /dev/nvidiactl ]"]
		onExited: (code, status) => {
			root.hasNvidia = (code === 0)
			root.videoCodec = root.hasNvidia ? "h264_nvenc" : "libx264"
		}
	}

	Process {
		id: depCheckProc
		stdout: StdioCollector {
			onStreamFinished: {
				var missing = text.trim().split("\n").filter(l => l !== "")
				if (missing.length > 0)
				console.warn("[ScreenRecorder] Missing dependencies:", missing.join(", "))
			}
		}
	}

	// ------------------------------------------------------------
	// Public entry points
	// ------------------------------------------------------------

	function toggleRecord(useArea) {
		if (root.recording) { stopRecord(); return }
		beginAction("record", useArea === true)
	}

	function toggleStream() {
		if (root.streaming) { stopStream(); return }
		beginAction("stream", false)   // streaming is always full-output; area selection isn't supported for it
	}

	function toggleGif(useArea) {
		if (root.recordingGif) { stopGif(); return }
		beginAction("gif", useArea === true)
	}

	// ------------------------------------------------------------
	// Monitor discovery (only prompts if there's more than one), or
	// slurp-based area selection when useArea is true
	// ------------------------------------------------------------

	function beginAction(kind, useArea) {
		root._pendingAction = kind
		if (useArea) {
			slurpProc.running = false
			slurpProc.running = true
		} else {
			monitorInfoProc.running = false
			monitorInfoProc.running = true
		}
	}

	Process {
		id: slurpProc
		command: ["slurp"]
		stdout: StdioCollector {
			onStreamFinished: {
				var geometry = text.trim()
				if (geometry === "") {
					// Empty output means the user cancelled (Escape) or slurp
					// isn't installed; either way there's nothing to record.
					if (root._pendingAction !== null) {
						root.actionFailed("area selection cancelled")
						root._pendingAction = null
					}
					return
				}
				root.runPendingAction(geometry, true)
			}
		}
	}

	Process {
		id: monitorInfoProc
		command: ["hyprctl", "monitors", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				var monitors = []
				try {
					monitors = JSON.parse(text)
				} catch (e) {
					root.actionFailed("could not read monitor list")
					root._pendingAction = null
					return
				}
				if (!monitors || monitors.length === 0) {
					root.actionFailed("no displays found")
					root._pendingAction = null
					return
				}
				if (monitors.length === 1) {
					root.runPendingAction(monitors[0].name, false)
				} else {
					monitorPicker.open(monitors)
				}
			}
		}
	}

	function runPendingAction(target, isGeometry) {
		if (root._pendingAction === "record") startRecord(target, isGeometry === true)
		else if (root._pendingAction === "stream") startStream(target)
		else if (root._pendingAction === "gif") startGif(target, isGeometry === true)
		root._pendingAction = null
	}

	// ------------------------------------------------------------
	// Audio source (always resolved fresh, mirrors the original script)
	// ------------------------------------------------------------

	function withAudioSource(callback) {
		sinkProc.callback = callback
		sinkProc.command = ["sh", "-c", "pactl get-default-sink 2>/dev/null || pactl info 2>/dev/null | awk -F': ' '/Default Sink/ {print $2}'"]
		sinkProc.running = false
		sinkProc.running = true
	}

	Process {
		id: sinkProc
		property var callback
		stdout: StdioCollector {
			onStreamFinished: {
				var sink = text.trim()
				if (sinkProc.callback) sinkProc.callback(sink !== "" ? sink + ".monitor" : "")
			}
		}
	}

	// ------------------------------------------------------------
	// Notifications
	// ------------------------------------------------------------

	Process {
		id: notifyProc
		function send(title, body) {
			notifyProc.command = ["notify-send", title, body]
			notifyProc.running = false
			notifyProc.running = true
		}
	}

	// ------------------------------------------------------------
	// Recording
	// ------------------------------------------------------------

	Process { id: killRecordProc }
	Process { id: killStreamProc }

	// Signals both the recorded PID and anything it spawned (kill -SIGINT
	// alone only hits the top-level process; wf-recorder shouldn't normally
	// fork children, but pkill -P covers it if it ever does).
	function killByPidFile(proc, pidFile) {
		proc.command = ["sh", "-c",
		"PID=$(cat \"$1\" 2>/dev/null); " +
		"if [ -n \"$PID\" ]; then kill -SIGINT \"$PID\" 2>/dev/null; pkill -SIGINT -P \"$PID\" 2>/dev/null; fi; " +
		"rm -f \"$1\"",
		"killByPidFile", pidFile
	]
	proc.running = false
	proc.running = true
}

function startRecord(target, isArea) {
	root.withAudioSource(function(audioSource) {
		var encoderOptsStr = root.hasNvidia ? "-p preset=p4 -p tune=hq" : "-p preset=ultrafast"
		var script = [
			"now=$(date '+%a__%b%d__%H_%M_%S')",
			"mkdir -p \"$HOME/Videos\"",
			"outputfile=\"$HOME/Videos/recording_${now}.mkv\"",
			// $6 carries "area" or "output" so one script handles both
			// -g (slurp geometry) and -o (whole monitor) cases.
			"if [ \"$6\" = \"area\" ]; then args=(-g \"$1\"); else args=(-o \"$1\"); fi",
			"if [ -n \"$2\" ]; then args+=(-a \"$2\"); fi",
			"args+=(-r \"$3\" -c \"$4\" -x yuv420p " + encoderOptsStr + " -f \"$outputfile\")",
			"wf-recorder \"${args[@]}\" &",
			"echo $! > \"$5\"",
			"wait"
		].join("\n")

		recordProc.command = ["bash", "-c", script, "record", target, audioSource, String(root.fpsRecord), root.videoCodec, root.recPidFile, isArea ? "area" : "output"]
		recordProc.running = false
		recordProc.running = true

		root.recording = true
		root.recordingOutput = isArea ? "Selected area" : target
		root.recordingStarted(root.recordingOutput)
		notifyProc.send("Recording", "Started" + (isArea ? " (area)" : " on " + target))
	})
}

Process {
	id: recordProc
	onExited: (code, status) => {
		// If we're still marked as recording when this exits, wf-recorder
		// died on its own (bad codec, no such device, crash, etc.)
		// rather than via stopRecord(), which always flips `recording`
		// to false itself before this fires. Previously nothing checked
		// this at all, so the UI kept claiming a recording was active
		// indefinitely after a failed start.
		if (root.recording) {
			console.warn("[ScreenRecorder] wf-recorder exited unexpectedly, code:", code)
			root.recording = false
			root.recordingOutput = ""
			root.recordingStopped()
			root.actionFailed("recording stopped unexpectedly (exit code " + code + ")")
			notifyProc.send("Recording Error", "wf-recorder exited unexpectedly (code " + code + ").")
		}
	}
}

function stopRecord() {
	killByPidFile(killRecordProc, root.recPidFile)

	root.recording = false
	root.recordingOutput = ""
	root.recordingStopped()
	notifyProc.send("Recording", "Stopped")
}

// ------------------------------------------------------------
// GIF recording
// ------------------------------------------------------------

Process { id: killGifProc }

function startGif(target, isArea) {
	var script = [
		"now=$(date '+%a__%b%d__%H_%M_%S')",
		"mkdir -p \"$HOME/Videos\"",
		"outputfile=\"$HOME/Videos/recording_${now}.gif\"",
		"if [ \"$3\" = \"area\" ]; then args=(-g \"$1\"); else args=(-o \"$1\"); fi",
		// wf-recorder's -c gif uses ffmpeg's built-in GIF encoder. It's
		// not as good as a proper gifski pipeline, but needs nothing
		// beyond wf-recorder itself. No -a/audio flag at all - GIF
		// can't carry sound.
		"args+=(-r \"$2\" -c gif -f \"$outputfile\")",
		"wf-recorder \"${args[@]}\" &",
		"echo $! > \"$4\"",
		"wait"
	].join("\n")

	gifProc.command = ["bash", "-c", script, "gif", target, String(root.fpsGif), isArea ? "area" : "output", root.gifPidFile]
	gifProc.running = false
	gifProc.running = true

	root.recordingGif = true
	root.gifOutput = isArea ? "Selected area" : target
	root.gifStarted(root.gifOutput)
	notifyProc.send("GIF Recording", "Started" + (isArea ? " (area)" : " on " + target))
}

Process {
	id: gifProc
	onExited: (code, status) => {
		if (root.recordingGif) {
			console.warn("[ScreenRecorder] gif recording exited unexpectedly, code:", code)
			root.recordingGif = false
			root.gifOutput = ""
			root.gifStopped()
			root.actionFailed("gif recording stopped unexpectedly (exit code " + code + ")")
			notifyProc.send("GIF Error", "Recording exited unexpectedly (code " + code + ").")
		}
	}
}

function stopGif() {
	killByPidFile(killGifProc, root.gifPidFile)

	root.recordingGif = false
	root.gifOutput = ""
	root.gifStopped()
	notifyProc.send("GIF Recording", "Stopped - converting may take a moment")
}

// ------------------------------------------------------------
// Streaming
// ------------------------------------------------------------

Process {
	id: streamKeyProc
	property var callback
	stdout: StdioCollector {
		onStreamFinished: {
			if (streamKeyProc.callback) streamKeyProc.callback(text.trim())
		}
	}
}

function startStream(output) {
	streamKeyProc.callback = function(key) {
		if (key === "") {
			root.actionFailed("TWITCH_TOKEN is not set")
			notifyProc.send("Stream Error", "TWITCH_TOKEN is not set!")
			return
		}
		root.withAudioSource(function(audioSource) {
			var encoderOptsStr = root.hasNvidia ? "-p preset=p4 -p tune=hq" : "-p preset=ultrafast"
			var script = [
				"args=(-o \"$1\")",
				"if [ -n \"$2\" ]; then args+=(-a \"$2\"); fi",
				"args+=(-r \"$3\" -c \"$4\" -x yuv420p " + encoderOptsStr +
				" -p rc=cbr -p bitrate=4500K -m flv -f \"rtmp://" + root.streamServer + ".live-video.net/app/$5\")",
				"wf-recorder \"${args[@]}\" &",
				"echo $! > \"$6\"",
				"wait"
			].join("\n")

			streamProc.command = ["bash", "-c", script, "stream", output, audioSource, String(root.fpsStream), root.videoCodec, key, root.streamPidFile]
			streamProc.running = false
			streamProc.running = true

			root.streaming = true
			root.streamingOutput = output
			root.streamingStarted(output)
			notifyProc.send("Stream", "Started on " + output)
		})
	}
	streamKeyProc.command = ["sh", "-c", "printf '%s' \"$TWITCH_TOKEN\""]
	streamKeyProc.running = false
	streamKeyProc.running = true
}

Process {
	id: streamProc
	onExited: (code, status) => {
		// Mirrors recordProc's handling: if we're still marked as
		// streaming when the process exits, it dropped on its own
		// (network failure, RTMP rejection, etc.) rather than via
		// stopStream(), and the user deserves to know their stream
		// isn't actually live anymore instead of finding out later.
		if (root.streaming) {
			console.warn("[ScreenRecorder] stream exited unexpectedly, code:", code)
			root.streaming = false
			root.streamingOutput = ""
			root.streamingStopped()
			root.actionFailed("stream stopped unexpectedly (exit code " + code + ")")
			notifyProc.send("Stream Error", "Stream exited unexpectedly (code " + code + ").")
		}
	}
}

function stopStream() {
	killByPidFile(killStreamProc, root.streamPidFile)

	root.streaming = false
	root.streamingOutput = ""
	root.streamingStopped()
	notifyProc.send("Stream", "Stopped")
}

// ------------------------------------------------------------
// NEW FUNCTION: Action Picker (Root scope - required for IPC)
// ------------------------------------------------------------

function showActionPicker() {
	actionPicker.open()
}

// ------------------------------------------------------------
// Monitor picker overlay (original)
// ------------------------------------------------------------

PanelWindow {
	id: monitorPicker
	screen: Quickshell.screens[0]
	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Normal
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
	anchors { top: true; bottom: true; left: true; right: true }

	property var monitorNames: []

	function open(monitors) {
		monitorPicker.monitorNames = monitors.map(function(m) { return m.name })
		monitorPicker.visible = true
	}

	function pick(name) {
		monitorPicker.visible = false
		root.runPendingAction(name, false)
	}

	function dismiss() {
		monitorPicker.visible = false
		root._pendingAction = null
	}

	MouseArea {
		anchors.fill: parent
		z: -1
		onClicked: monitorPicker.dismiss()
	}

	Rectangle {
		width: 320
		height: Math.min(420, 130 + monitorPicker.monitorNames.length * 46)
		anchors.centerIn: parent
		radius: 16
		color: root.cal0
		border.width: 2
		border.color: root.cal3

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 16
			spacing: 10

			Text {
				text: "Select display"
				color: root.cal6
				font.family: root.fontFamily
				font.pixelSize: root.fontSize + 4
				font.bold: true
			}

			ListView {
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				spacing: 6
				model: monitorPicker.monitorNames

				delegate: Rectangle {
					width: ListView.view.width
					height: 40
					radius: 10
					color: root.cal2
					border.width: 1
					border.color: root.cal3

					Text {
						anchors.centerIn: parent
						text: modelData
						color: root.cal6
						font.family: root.fontFamily
						font.pixelSize: root.fontSize
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						hoverEnabled: true
						onEntered: parent.border.color = root.cal14
						onExited: parent.border.color = root.cal3
						onClicked: monitorPicker.pick(modelData)
					}
				}
			}

			Rectangle {
				Layout.preferredWidth: 100
				Layout.preferredHeight: 28
				Layout.alignment: Qt.AlignHCenter
				radius: 14
				color: root.cal2
				border.width: 2
				border.color: root.cal3

				Text {
					anchors.centerIn: parent
					text: "Cancel"
					color: root.cal6
					font.family: root.fontFamily
					font.pixelSize: root.fontSize - 1
				}

				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					hoverEnabled: true
					onClicked: monitorPicker.dismiss()
				}
			}
		}
	}
}

// ------------------------------------------------------------
// NEW: Action Picker overlay (Record vs Stream selection)
// ------------------------------------------------------------

PanelWindow {
	id: actionPicker
	screen: Quickshell.screens[0]
	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Normal
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
	anchors { top: true; bottom: true; left: true; right: true }

	function open() {
		actionPicker.visible = true
	}

	function dismiss() {
		actionPicker.visible = false
	}

	// Applies to Record and GIF. Streaming stays full-output only.
	property bool useArea: false

	MouseArea {
		anchors.fill: parent
		z: -1
		onClicked: actionPicker.dismiss()
	}

	Rectangle {
		width: 320
		height: 300
		anchors.centerIn: parent
		radius: 16
		color: root.cal0
		border.width: 2
		border.color: root.cal3

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: 16
			spacing: 12

			Text {
				text: "Screen Action"
				color: root.cal6
				font.family: root.fontFamily
				font.pixelSize: root.fontSize + 4
				font.bold: true
				Layout.alignment: Qt.AlignHCenter
				Layout.bottomMargin: 4
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 32
				radius: 10
				color: actionPicker.useArea ? root.cal14 : root.cal2
				border.width: 1
				border.color: root.cal3

				Text {
					anchors.centerIn: parent
					text: actionPicker.useArea ? " Selecting area on start" : " Full screen (tap to select an area)"
					color: actionPicker.useArea ? root.cal6 : root.cal6
					font.family: root.fontFamily
					font.pixelSize: root.fontSize - 1
					font.bold: actionPicker.useArea
				}

				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					hoverEnabled: true
					onClicked: actionPicker.useArea = !actionPicker.useArea
					onEntered: {
						parent.color = "#7c6f64"
						parent.border.color = root.cal14
					}
					onExited: {
						parent.color = "#504945"
						parent.border.color = root.cal3
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 12

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 40
					radius: 10
					color: root.cal2
					border.width: 1
					border.color: root.cal3

					Text {
						anchors.centerIn: parent
						text: root.recording ? " Stop Record" : " Start Record"
						color: root.recording ? root.cal8 : root.cal6
						font.family: root.fontFamily
						font.pixelSize: root.fontSize
						font.bold: true
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						hoverEnabled: true
						onClicked: {
							var useArea = actionPicker.useArea
							actionPicker.dismiss()
							root.toggleRecord(useArea)
						}
						onEntered: {
							parent.color = "#7c6f64"
							parent.border.color = root.cal14
						}
						onExited: {
							parent.color = "#504945"
							parent.border.color = root.cal3
						}

					}
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 40
					radius: 10
					color: root.cal2
					border.width: 1
					border.color: root.cal3

					Text {
						anchors.centerIn: parent
						text: root.streaming ? " Stop Stream" : "  Start Stream"
						color: root.streaming ? root.cal8 : root.cal6
						font.family: root.fontFamily
						font.pixelSize: root.fontSize
						font.bold: true
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						hoverEnabled: true
						onClicked: {
							actionPicker.dismiss()
							root.toggleStream()
						}
						onEntered: {
							parent.color = "#7c6f64"
							parent.border.color = root.cal14
						}
						onExited: {
							parent.color = "#504945"
							parent.border.color = root.cal3
						}
					}
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 40
				radius: 10
				color: root.cal2
				border.width: 1
				border.color: root.cal3

				Text {
					anchors.centerIn: parent
					text: root.recordingGif ? " Stop GIF" : " Start GIF"
					color: root.recordingGif ? root.cal8 : root.cal6
					font.family: root.fontFamily
					font.pixelSize: root.fontSize
					font.bold: true
				}

				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					hoverEnabled: true
					onClicked: {
						var useArea = actionPicker.useArea
						actionPicker.dismiss()
						root.toggleGif(useArea)
					}
					onEntered: {
						parent.color = "#7c6f64"
						parent.border.color = root.cal14
					}
					onExited: {
						parent.color = "#504945"
						parent.border.color = root.cal3
					}
				}
			}

			// Subtle status info
			Text {
				Layout.fillWidth: true
				text: {
					if (root.recording) return " Currently recording"
					if (root.streaming) return " Currently streaming"
					if (root.recordingGif) return " Currently recording GIF"
					return " No active session"
				}
				color: root.cal10
				font.pixelSize: root.fontSize - 1
				horizontalAlignment: Text.AlignHCenter
			}

			Rectangle {
				Layout.preferredWidth: 100
				Layout.preferredHeight: 28
				Layout.alignment: Qt.AlignHCenter
				Layout.topMargin: 4
				radius: 14
				color: root.cal2
				border.width: 2
				border.color: root.cal3

				Text {
					anchors.centerIn: parent
					text: "Cancel"
					color: root.cal6
					font.family: root.fontFamily
					font.pixelSize: root.fontSize - 1
				}

				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					hoverEnabled: true
					onClicked: actionPicker.dismiss()
					onEntered: {
						parent.color = "#7c6f64"
						parent.border.color = "#ebdbb2"
					}
					onExited: {
						parent.color = "#504945"
						parent.border.color = "#7c6f64"
					}
				}
			}
		}
	}
}
}
