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

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13

    // Fetch networks immediately when the panel is opened
    onActiveChanged: {
        if (active) scanNetworks()
    }

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

            // Start at 0; terse mode (-t) does not output a header row
            for (var i = 0; i < lines.length; i++) {
                if (!lines[i]) continue

                var parts = lines[i].split(':')
                if (parts.length >= 4) {
                    list.push({
                        inUse: parts[0] === '*',
                        ssid: parts[1],
                        security: parts[2],
                        signal: parseInt(parts[3])
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

    PanelWindow {
        id: wifiWindow
        screen: Quickshell.screens[0]
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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
                        id: wifiToggle
                        width: 60
                        height: 30
                        radius: 15
                        color: root.wifiEnabled ? "#83a598" : "#fb4934"
                        border.width: 2
                        border.color: "#7c6f64"
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
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: wifiToggle.border.color = "#ebdbb2"
                            onExited: wifiToggle.border.color = "#7c6f64"
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
                        border.width: 1
                        border.color: modelData.inUse ? "#7c6f64" : "#504945"
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
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.border.color = "#ebdbb2"
                            onExited: parent.border.color = modelData.inUse ? "#7c6f64" : "#504945"
                            onClicked: {
                                if (modelData.inUse) root.disconnectCurrent()
                                else root.connectTo(modelData.ssid, "")
                            }
                        }
                    }
                }

                Rectangle {
                    id: wifiCloseBtn
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    radius: 15
                    color: "#504945"
                    border.width: 2
                    border.color: "#7c6f64"
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
                            wifiCloseBtn.color = "#7c6f64"
                            wifiCloseBtn.border.color = "#ebdbb2"
                        }
                        onExited: {
                            wifiCloseBtn.color = "#504945"
                            wifiCloseBtn.border.color = "#7c6f64"
                        }
                        onClicked: root.active = false
                    }
                }
            }
        }
    }
}
