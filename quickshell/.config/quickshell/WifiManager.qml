import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

Item {
    id: root

    property bool active: false
    property var networks: []
    property bool wifiEnabled: true
    property string connectedSsid: ""

    Process {
        id: nmcliProc
        property var callback
        function run(args) {
            command = args
            running = false
            running = true
        }
        onExited: {
            if (callback) {
                var cb = callback
                callback = null
                cb(exitCode, stdout)
            }
        }
    }

    Timer {
        interval: 3000
        running: root.active
        repeat: true
        onTriggered: scanNetworks()
    }

    function scanNetworks() {
        nmcliProc.callback = function(code, out) {
            if (code !== 0) return
            var lines = out.trim().split('\n')
            var list = []
            for (var i = 1; i < lines.length; i++) {
                var parts = lines[i].split(':')
                if (parts.length >= 4) {
                    list.push({
                        ssid: parts[1],
                        signal: parseInt(parts[3]),
                        security: parts[2],
                        inUse: parts[0] === '*'
                    })
                }
            }
            networks = list
        }
        nmcliProc.run(["nmcli", "-t", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list"])
    }

    function toggleWifi() {
        nmcliProc.run(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"])
        wifiEnabled = !wifiEnabled
    }

    function connectTo(ssid, password) {
        if (!password) password = ""
        nmcliProc.run(["nmcli", "device", "wifi", "connect", ssid, "password", password])
    }

    function disconnectCurrent() {
        nmcliProc.run(["nmcli", "device", "disconnect", "wlan0"])
    }

    // Overlay - full-screen panel with centered rectangle
    PanelWindow {
        id: wifiWindow
        screen: Quickshell.screens[0]
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        anchors { top: true; bottom: true; left: true; right: true }

        Rectangle {
            width: 360
            height: 480
            anchors.centerIn: parent
            radius: 16
            color: "#282828"
            border.width: 2
            border.color: "#7c6f64"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "WiFi"
                        color: "#ebdbb2"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize + 4
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 60
                        height: 30
                        radius: 15
                        color: root.wifiEnabled ? "#83a598" : "#fb4934"
                        Text {
                            anchors.centerIn: parent
                            text: root.wifiEnabled ? "On" : "Off"
                            color: "#282828"
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleWifi()
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.networks

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 40
                        radius: 8
                        color: modelData.inUse ? "#3c3836" : "#504945"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 8
                            Text {
                                text: modelData.ssid ? modelData.ssid : ""
                                color: "#ebdbb2"
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.signal !== undefined ? modelData.signal + "%" : ""
                                color: "#fabd2f"
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize - 2
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.inUse) {
                                    root.disconnectCurrent()
                                } else {
                                    root.connectTo(modelData.ssid, "")
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    radius: 15
                    color: "#504945"
                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        color: "#ebdbb2"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.active = false
                    }
                }
            }
        }
    }
}
