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
    property string recordingOutput: ""
    property string streamingOutput: ""

    signal recordingStarted(string output)
    signal recordingStopped()
    signal streamingStarted(string output)
    signal streamingStopped()
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
    readonly property string streamServer: "ingest.global-contribute"

    readonly property string recPidFile: "/tmp/qs-recpid"
    readonly property string streamPidFile: "/tmp/qs-streampid"

    property bool hasNvidia: false
    property string videoCodec: "libx264"

    property var _pendingAction: null   // "record" | "stream"

    Component.onCompleted: {
        nvidiaCheckProc.running = true

        depCheckProc.command = ["sh", "-c", "for c in wf-recorder notify-send pactl hyprctl; do command -v \"$c\" >/dev/null || echo \"$c\"; done"]
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

    function toggleRecord() {
        if (root.recording) { stopRecord(); return }
        beginAction("record")
    }

    function toggleStream() {
        if (root.streaming) { stopStream(); return }
        beginAction("stream")
    }

    // ------------------------------------------------------------
    // Monitor discovery (only prompts if there's more than one)
    // ------------------------------------------------------------

    function beginAction(kind) {
        root._pendingAction = kind
        monitorInfoProc.running = false
        monitorInfoProc.running = true
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
                    root.runPendingAction(monitors[0].name)
                } else {
                    monitorPicker.open(monitors)
                }
            }
        }
    }

    function runPendingAction(output) {
        if (root._pendingAction === "record") startRecord(output)
        else if (root._pendingAction === "stream") startStream(output)
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

    Process { id: recordProc }
    Process { id: killProc }

    function startRecord(output) {
        root.withAudioSource(function(audioSource) {
            var encoderOptsStr = root.hasNvidia ? "-p preset=p4 -p tune=hq" : "-p preset=ultrafast"
            var script = [
                "now=$(date '+%a__%b%d__%H_%M_%S')",
                "mkdir -p \"$HOME/Videos\"",
                "outputfile=\"$HOME/Videos/recording_${now}.mkv\"",
                "wf-recorder -o \"$1\" -a \"$2\" -r \"$3\" -c \"$4\" -x yuv420p " + encoderOptsStr + " -f \"$outputfile\" &",
                "echo $! > \"$5\"",
                "wait"
            ].join("\n")

            recordProc.command = ["bash", "-c", script, "record", output, audioSource, String(root.fpsRecord), root.videoCodec, root.recPidFile]
            recordProc.running = false
            recordProc.running = true

            root.recording = true
            root.recordingOutput = output
            root.recordingStarted(output)
            notifyProc.send("Recording", "Started on " + output)
        })
    }

    function stopRecord() {
        killProc.command = ["sh", "-c", "kill -SIGINT \"$(cat '" + root.recPidFile + "' 2>/dev/null)\" 2>/dev/null; rm -f '" + root.recPidFile + "'"]
        killProc.running = false
        killProc.running = true

        root.recording = false
        root.recordingOutput = ""
        root.recordingStopped()
        notifyProc.send("Recording", "Stopped")
    }

    // ------------------------------------------------------------
    // Streaming
    // ------------------------------------------------------------

    Process { id: streamProc }

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
                    "wf-recorder -o \"$1\" -a \"$2\" -r \"$3\" -c \"$4\" -x yuv420p " + encoderOptsStr +
                        " -p rc=cbr -p bitrate=4500K -m flv -f \"rtmp://" + root.streamServer + ".live-video.net/app/$5\" &",
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

    function stopStream() {
        killProc.command = ["sh", "-c", "kill -SIGINT \"$(cat '" + root.streamPidFile + "' 2>/dev/null)\" 2>/dev/null; rm -f '" + root.streamPidFile + "'"]
        killProc.running = false
        killProc.running = true

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
            root.runPendingAction(name)
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

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: actionPicker.dismiss()
        }

        Rectangle {
            width: 320
            height: 220
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
                            onEntered: parent.border.color = root.cal14
                            onExited: parent.border.color = root.cal3
                            onClicked: {
                                actionPicker.dismiss()
                                root.toggleRecord()
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
                            onEntered: parent.border.color = root.cal14
                            onExited: parent.border.color = root.cal3
                            onClicked: {
                                actionPicker.dismiss()
                                root.toggleStream()
                            }
                        }
                    }
                }

                // Subtle status info
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (root.recording) return " Currently recording"
                        if (root.streaming) return " Currently streaming"
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
                    }
                }
            }
        }
    }
}
