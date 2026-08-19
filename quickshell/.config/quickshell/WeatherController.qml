import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

Item {
    id: root

    property bool active: false
    property string weatherIcon: "󰖐"
    property string weatherText: ""

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13

    Process {
        id: weatherProc
        command: ["sysstats", "weather"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherText = text.trim()
                var parts = root.weatherText.split(' ')
                if (parts.length >= 1) root.weatherIcon = parts[0]
                if (parts.length >= 2) root.weatherText = parts.slice(1).join(' ')
            }
        }
    }

    Timer {
        interval: 600000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            weatherProc.running = false
            weatherProc.running = true
        }
    }

    PanelWindow {
        id: weatherWindow
        screen: Quickshell.screens[0]
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; bottom: true; left: true; right: true }

        Rectangle {
            width: 300
            height: 200
            anchors.centerIn: parent
            radius: 16
            color: "#282828"
            border.width: 2
            border.color: "#83a598"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: root.weatherIcon
                    color: "#83a598"
                    font.family: root.fontFamily
                    font.pixelSize: 48
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: root.weatherText !== "" ? root.weatherText : "--"
                    color: "#ebdbb2"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 2
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    id: weatherCloseBtn
                    width: 100
                    height: 30
                    radius: 15
                    color: "#504945"
                    border.width: 2
                    border.color: "#7c6f64"
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        color: "#ebdbb2"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: {
                            weatherCloseBtn.color = "#7c6f64"
                            weatherCloseBtn.border.color = "#ebdbb2"
                        }
                        onExited: {
                            weatherCloseBtn.color = "#504945"
                            weatherCloseBtn.border.color = "#7c6f64"
                        }
                        onClicked: root.active = false
                    }
                }
            }
        }
    }
}
