import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick.Layouts

PanelWindow {
    id: root
    property bool active: false
    visible: active

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

    // Streams, not hardware devices: isStream picks out per-application
    // nodes rather than physical sinks/sources. Direction follows the same
    // "isSink = audio flows into this node" rule as the hardware devices
    // in AudioSwitcher: a playback stream (an app's audio going out to a
    // speaker) is a source of audio into the graph, so isSink is false; a
    // recording stream (an app capturing from a mic) accepts audio routed
    // into it, so isSink is true.
    readonly property var playbackStreams: Pipewire.nodes.values.filter(function(n) {
        return n.audio && n.isStream && !n.isSink
    })
    readonly property var recordingStreams: Pipewire.nodes.values.filter(function(n) {
        return n.audio && n.isStream && n.isSink
    })

    readonly property var sinks: Pipewire.nodes.values.filter(function(n) {
        return n.audio && !n.isStream && n.isSink
    })
    readonly property var sources: Pipewire.nodes.values.filter(function(n) {
        return n.audio && !n.isStream && !n.isSink
    })

    PwObjectTracker { objects: root.playbackStreams.concat(root.recordingStreams).concat(root.sinks).concat(root.sources) }

    function appLabel(node) {
        var props = node.properties || {}
        return props["application.name"] || node.description || node.nickname || node.name
    }

    function deviceLabel(node) {
        return node.description || node.nickname || node.name
    }

    // Quickshell's Pipewire binding doesn't expose stream rerouting
    // directly, so this falls back to pactl (which understands the same
    // pipewire graph via pipewire-pulse) for exactly this one operation.
    // Everything else here (volume, mute) is done through the native
    // property writes above, no subprocess involved.
    Process { id: moveProc }

    function moveStream(node, targetDevice, kind) {
        var verb = kind === "sink" ? "move-sink-input" : "move-source-output"
        moveProc.command = ["pactl", verb, String(node.id), targetDevice.name]
        moveProc.running = false
        moveProc.running = true
    }

    Rectangle {
        width: 640
        height: 560
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
                text: "Application Volume"
                color: cal6
                font.family: root.fontFamily
                font.pixelSize: root.fontSize + 4
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    Text { text: "Playback"; color: cal14; font.family: root.fontFamily; font.pixelSize: root.fontSize + 2 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: root.playbackStreams
                        delegate: streamDelegate
                        property string kind: "sink"

                        Text {
                            visible: parent.count === 0
                            anchors.centerIn: parent
                            text: "Nothing playing audio right now"
                            color: cal3
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    Text { text: "Recording"; color: cal14; font.family: root.fontFamily; font.pixelSize: root.fontSize + 2 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: root.recordingStreams
                        delegate: streamDelegate
                        property string kind: "source"

                        Text {
                            visible: parent.count === 0
                            anchors.centerIn: parent
                            text: "Nothing recording audio right now"
                            color: cal3
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
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

    Component {
        id: streamDelegate
        Rectangle {
            id: streamRow
            required property var modelData
            // ListView.view.kind carries which list ("sink" for playback,
            // "source" for recording) this delegate belongs to, since a
            // shared Component doesn't otherwise know which ListView it's in.
            readonly property string kind: ListView.view.kind
            property bool deviceMenuOpen: false

            width: ListView.view.width
            height: deviceMenuOpen ? 128 : 68
            radius: 10
            color: cal2
            border.width: 1
            border.color: cal3
            clip: true

            Behavior on height { NumberAnimation { duration: 100 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: root.appLabel(streamRow.modelData)
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        // "Move to another device" toggle
                        text: "\uf1de"
                        color: streamRow.deviceMenuOpen ? cal14 : cal3
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: streamRow.deviceMenuOpen = !streamRow.deviceMenuOpen
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: streamRow.modelData.audio.muted ? "\uf6a9" : "\uf028"
                        color: streamRow.modelData.audio.muted ? cal3 : cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                        }
                    }
                    VolumeSlider {
                        Layout.fillWidth: true
                        value: streamRow.modelData.audio.volume
                        muted: streamRow.modelData.audio.muted
                        onMoved: (v) => streamRow.modelData.audio.volume = v
                    }
                    Text {
                        Layout.preferredWidth: 36
                        text: Math.round(streamRow.modelData.audio.volume * 100) + "%"
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 2
                    }
                }

                ListView {
                    visible: streamRow.deviceMenuOpen
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    clip: true
                    orientation: ListView.Horizontal
                    spacing: 6
                    model: streamRow.kind === "sink" ? root.sinks : root.sources

                    delegate: Rectangle {
                        id: deviceOption
                        required property var modelData
                        width: 140
                        height: 44
                        radius: 8
                        color: cal0
                        border.width: 1
                        border.color: cal3
                        Text {
                            anchors.fill: parent
                            anchors.margins: 6
                            text: root.deviceLabel(deviceOption.modelData)
                            color: cal6
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.border.color = cal14
                            onExited: parent.border.color = cal3
                            onClicked: {
                                root.moveStream(streamRow.modelData, deviceOption.modelData, streamRow.kind)
                                streamRow.deviceMenuOpen = false
                            }
                        }
                    }
                }
            }
        }
    }
}
