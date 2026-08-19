import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

PanelWindow {
    id: root
    property bool active: false
    visible: active

    property var sinks: []
    property var sources: []

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13
    readonly property color cal0: "#282828"
    readonly property color cal2: "#504945"
    readonly property color cal3: "#7c6f64"
    readonly property color cal6: "#ebdbb2"
    readonly property color cal14: "#fe8019"

    screen: Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; bottom: true; left: true; right: true }

    Process {
        id: sinkProc
        command: ["pactl", "list", "short", "sinks"]
        stdout: StdioCollector {}
        onExited: (code, status) => {
            console.warn("[AudioSwitcher] sinkProc exited, code:", code)
            if (code === 0) {
                var text = sinkProc.stdout.text
                var lines = text.trim().split("\n").filter(s => s !== "")
                var arr = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(/\s+/)
                    if (parts.length >= 2)
                        arr.push({ name: parts[1], desc: parts.slice(2).join(" ") || parts[1] })
                }
                root.sinks = arr
                console.warn("[AudioSwitcher] Sinks loaded:", arr.length)
            }
        }
    }

    Process {
        id: sourceProc
        command: ["pactl", "list", "short", "sources"]
        stdout: StdioCollector {}
        onExited: (code, status) => {
            console.warn("[AudioSwitcher] sourceProc exited, code:", code)
            if (code === 0) {
                var text = sourceProc.stdout.text
                var lines = text.trim().split("\n").filter(s => s !== "")
                var arr = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(/\s+/)
                    if (parts.length >= 2)
                        arr.push({ name: parts[1], desc: parts.slice(2).join(" ") || parts[1] })
                }
                root.sources = arr
                console.warn("[AudioSwitcher] Sources loaded:", arr.length)
            }
        }
    }

    function refreshDevices() {
        sinkProc.running = false
        sinkProc.running = true
        sourceProc.running = false
        sourceProc.running = true
        console.warn("[AudioSwitcher] refreshDevices called")
    }

    Process { id: setProc }
    function setDefault(device, type) {
        setProc.command = (type === "sink") ? ["pactl", "set-default-sink", device] : ["pactl", "set-default-source", device]
        setProc.running = false
        setProc.running = true
        root.active = false
    }

    onActiveChanged: {
        if (active) refreshDevices()
    }

    Rectangle {
        width: 700
        height: 500
        anchors.centerIn: parent
        radius: 16
        color: cal0
        border.width: 2
        border.color: cal3

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "Audio Devices"
                color: cal6
                font.family: root.fontFamily
                font.pixelSize: root.fontSize + 4
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Text { text: "Outputs"; color: cal14; font.family: root.fontFamily; font.pixelSize: root.fontSize + 2 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: root.sinks
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 50
                            radius: 10
                            color: cal2
                            border.width: 1
                            border.color: cal3
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: modelData.desc; color: cal6; font.family: root.fontFamily; font.pixelSize: root.fontSize }
                                Text { text: modelData.name; color: cal3; font.family: root.fontFamily; font.pixelSize: root.fontSize - 2 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.border.color = cal14
                                onExited: parent.border.color = cal3
                                onClicked: root.setDefault(modelData.name, "sink")
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Text { text: "Inputs"; color: cal14; font.family: root.fontFamily; font.pixelSize: root.fontSize + 2 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: root.sources
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 50
                            radius: 10
                            color: cal2
                            border.width: 1
                            border.color: cal3
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: modelData.desc; color: cal6; font.family: root.fontFamily; font.pixelSize: root.fontSize }
                                Text { text: modelData.name; color: cal3; font.family: root.fontFamily; font.pixelSize: root.fontSize - 2 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.border.color = cal14
                                onExited: parent.border.color = cal3
                                onClicked: root.setDefault(modelData.name, "source")
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: closeBtn
                Layout.preferredWidth: 120
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignHCenter
                radius: 15
                color: cal2
                border.width: 2
                border.color: cal3
                Text {
                    anchors.centerIn: parent
                    text: "Close"
                    color: cal6
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: { closeBtn.color = cal3; closeBtn.border.color = cal6 }
                    onExited: { closeBtn.color = cal2; closeBtn.border.color = cal3 }
                    onClicked: root.active = false
                }
            }
        }
    }
}
