import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts
import QtCore

PanelWindow {
    id: root

    property bool active: false
    visible: active

    property string nerdfontFile: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/nerdfont-picker/nerdfont.txt"
    property var allIcons: []
    property string searchText: ""

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
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { top: true; bottom: true; left: true; right: true }

    FileView {
        id: iconFileView
        path: root.nerdfontFile
        onLoaded: {
            var content = text()
            if (content !== "") {
                root.allIcons = content.trim().split("\n")
            }
        }
    }

    readonly property var filteredIcons: {
        if (searchText === "") return allIcons
        return allIcons.filter(function(e) {
            return e.toLowerCase().includes(searchText.toLowerCase())
        })
    }

    Process {
        id: copyProc
        property string selectedIcon
        onExited: (code, status) => {
            if (code === 0) root.active = false
        }
    }

    function copyIcon(icon) {
        copyProc.selectedIcon = icon
        copyProc.command = ["wl-copy", "--", icon]
        copyProc.running = false
        copyProc.running = true
    }

    onVisibleChanged: {
        if (visible) focusTimer.start()
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Rectangle {
        width: 480
        height: 600
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
                text: "Nerd Font Icon Picker"
                color: cal6
                font.family: root.fontFamily
                font.pixelSize: root.fontSize + 4
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 10
                color: cal2
                border.width: 2
                border.color: cal3

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 10
                    color: cal6
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    onTextChanged: root.searchText = text
                    Keys.onEscapePressed: root.active = false
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredIcons

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 40
                    radius: 10
                    color: cal2
                    border.width: 1
                    border.color: cal3

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        Text {
                            text: modelData.split(" ")[0]
                            color: cal6
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize + 4
                        }

                        Text {
                            text: modelData.substring(modelData.indexOf(" ") + 1)
                            color: cal6
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.border.color = cal14
                        onExited: parent.border.color = cal3
                        onClicked: root.copyIcon(modelData.split(" ")[0])
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
