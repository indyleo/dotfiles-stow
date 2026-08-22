import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick.Layouts

PanelWindow {
    id: root
    property bool active: false
    visible: active

    // Colors/font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize
    readonly property color cal0: Theme.cal0
    readonly property color cal2: Theme.cal2
    readonly property color cal3: Theme.cal3
    readonly property color cal6: Theme.cal6
    readonly property color cal14: Theme.cal14

    screen: Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    anchors { top: true; bottom: true; left: true; right: true }

    // Previously this parsed `pactl list short sinks` by splitting on
    // whitespace. That short format is index/name/driver/sample-spec/state -
    // there is no human-readable description field in it at all, so what
    // was labelled "desc" was actually just the driver name or blank. It
    // also broke outright on any device whose driver field happened to
    // contain extra whitespace-separated tokens.
    //
    // Quickshell ships a native PipeWire binding (already used in
    // AudioController.qml) that exposes real node metadata directly, so
    // there's no text format to misparse and no subprocess that can fail
    // silently.
    readonly property var allSinkNodes: Pipewire.nodes.values.filter(function(n) {
        return !n.isStream && n.isSink
    })
    readonly property var allSourceNodes: Pipewire.nodes.values.filter(function(n) {
        return !n.isStream && !n.isSink
    })

    PwObjectTracker { objects: root.allSinkNodes.concat(root.allSourceNodes) }

    readonly property var sinks: root.allSinkNodes.filter(function(n) { return n.audio })
    readonly property var sources: root.allSourceNodes.filter(function(n) { return n.audio })

    signal requestMixer()

    function deviceLabel(node) {
        return node.description || node.nickname || node.name
    }

    function setDefault(node, type) {
        if (type === "sink") Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
        root.active = false
    }

    Rectangle {
        width: 700
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

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Audio Devices"
                    color: cal6
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 4
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    id: perAppBtn
                    Layout.preferredWidth: perAppText.implicitWidth + 24
                    Layout.preferredHeight: 30
                    radius: 15
                    color: cal2
                    border.width: 1
                    border.color: cal3
                    Text {
                        id: perAppText
                        anchors.centerIn: parent
                        text: "\uf1de  Per-App Volume"
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: { perAppBtn.color = cal3; perAppBtn.border.color = cal14 }
                        onExited: { perAppBtn.color = cal2; perAppBtn.border.color = cal3 }
                        onClicked: { root.active = false; root.requestMixer() }
                    }
                }
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
                            id: sinkDelegate
                            required property var modelData
                            readonly property bool isDefault: modelData === Pipewire.defaultAudioSink
                            // Some nodes (e.g. a suspended/idle HDMI output nobody's
                            // using) expose a valid .audio object but haven't
                            // populated .volume/.muted yet, or PipeWire genuinely
                            // has no volume to report until the device becomes
                            // active. Falling back cleanly here (instead of NaN
                            // propagating into the slider's width math, or an
                            // exception blanking the percent text) keeps the row
                            // looking correct either way.
                            readonly property bool hasAudioData: modelData.audio != null && isFinite(modelData.audio.volume)
                            readonly property real safeVolume: hasAudioData ? modelData.audio.volume : 0
                            readonly property bool safeMuted: modelData.audio != null ? !!modelData.audio.muted : false
                            width: ListView.view.width
                            height: 64
                            radius: 10
                            color: cal2
                            border.width: isDefault ? 2 : 1
                            border.color: isDefault ? cal14 : cal3

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: if (!sinkDelegate.isDefault) parent.border.color = cal14
                                onExited: if (!sinkDelegate.isDefault) parent.border.color = cal3
                                onClicked: root.setDefault(sinkDelegate.modelData, "sink")
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: root.deviceLabel(sinkDelegate.modelData); color: cal6; font.family: root.fontFamily; font.pixelSize: root.fontSize }
                                        Text { text: sinkDelegate.modelData.name; color: cal3; font.family: root.fontFamily; font.pixelSize: root.fontSize - 2 }
                                    }
                                    Text {
                                        visible: sinkDelegate.isDefault
                                        text: "\uf00c"
                                        color: cal14
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        text: sinkDelegate.safeMuted ? "\uf6a9" : "\uf028"
                                        color: sinkDelegate.safeMuted ? cal3 : cal6
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: sinkDelegate.modelData.audio != null
                                            onClicked: sinkDelegate.modelData.audio.muted = !sinkDelegate.modelData.audio.muted
                                        }
                                    }
                                    VolumeSlider {
                                        Layout.fillWidth: true
                                        value: sinkDelegate.safeVolume
                                        muted: sinkDelegate.safeMuted
                                        onMoved: (v) => { if (sinkDelegate.modelData.audio != null) sinkDelegate.modelData.audio.volume = v }
                                    }
                                    Text {
                                        Layout.preferredWidth: 36
                                        text: sinkDelegate.hasAudioData ? Math.round(sinkDelegate.safeVolume * 100) + "%" : "--"
                                        color: cal6
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize - 2
                                    }
                                }
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
                            id: sourceDelegate
                            required property var modelData
                            readonly property bool isDefault: modelData === Pipewire.defaultAudioSource
                            readonly property bool hasAudioData: modelData.audio != null && isFinite(modelData.audio.volume)
                            readonly property real safeVolume: hasAudioData ? modelData.audio.volume : 0
                            readonly property bool safeMuted: modelData.audio != null ? !!modelData.audio.muted : false
                            width: ListView.view.width
                            height: 64
                            radius: 10
                            color: cal2
                            border.width: isDefault ? 2 : 1
                            border.color: isDefault ? cal14 : cal3

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: if (!sourceDelegate.isDefault) parent.border.color = cal14
                                onExited: if (!sourceDelegate.isDefault) parent.border.color = cal3
                                onClicked: root.setDefault(sourceDelegate.modelData, "source")
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: root.deviceLabel(sourceDelegate.modelData); color: cal6; font.family: root.fontFamily; font.pixelSize: root.fontSize }
                                        Text { text: sourceDelegate.modelData.name; color: cal3; font.family: root.fontFamily; font.pixelSize: root.fontSize - 2 }
                                    }
                                    Text {
                                        visible: sourceDelegate.isDefault
                                        text: "\uf00c"
                                        color: cal14
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        text: sourceDelegate.safeMuted ? "\uf131" : "\uf130"
                                        color: sourceDelegate.safeMuted ? cal3 : cal6
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: sourceDelegate.modelData.audio != null
                                            onClicked: sourceDelegate.modelData.audio.muted = !sourceDelegate.modelData.audio.muted
                                        }
                                    }
                                    VolumeSlider {
                                        Layout.fillWidth: true
                                        value: sourceDelegate.safeVolume
                                        muted: sourceDelegate.safeMuted
                                        onMoved: (v) => { if (sourceDelegate.modelData.audio != null) sourceDelegate.modelData.audio.volume = v }
                                    }
                                    Text {
                                        Layout.preferredWidth: 36
                                        text: sourceDelegate.hasAudioData ? Math.round(sourceDelegate.safeVolume * 100) + "%" : "--"
                                        color: cal6
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize - 2
                                    }
                                }
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