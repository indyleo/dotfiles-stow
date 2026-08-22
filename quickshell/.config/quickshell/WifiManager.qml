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

    // User-visible feedback for the last action (connect/disconnect/toggle).
    property string statusMessage: ""
    property bool connecting: false

    // Password prompt state
    property bool passwordDialogVisible: false
    property string pendingSsid: ""

    // Font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize

    // Fetch networks immediately when the panel is opened
    onActiveChanged: {
        if (active) scanNetworks()
    }

    // Dedicated process for periodic scanning. Kept separate from the
    // action process below so a connect/disconnect/toggle triggered by the
    // user can never overwrite (and silently drop) an in-flight scan
    // callback, or vice versa.
    Process {
        id: nmcliScanProc
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

    // Dedicated process for user-initiated actions (connect, disconnect,
    // toggle radio). Kept separate from nmcliScanProc for the same reason.
    Process {
        id: nmcliActionProc
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

    // Clears a transient status message after a few seconds so it doesn't
    // linger forever on screen.
    Timer {
        id: statusClearTimer
        interval: 4000
        onTriggered: root.statusMessage = ""
    }

    function scanNetworks() {
        nmcliScanProc.callback = function(code, out) {
            if (code !== 0) return
            var lines = out.trim().split('\n')
            var list = []

            // Start at 0; terse mode (-t) does not output a header row
            for (var i = 0; i < lines.length; i++) {
                if (!lines[i]) continue

                var parts = splitNmcliFields(lines[i])
                if (parts.length >= 4) {
                    list.push({
                        inUse: parts[0] === '*',
                        ssid: parts[1],
                        security: parts[2],
                        signal: parseInt(parts[3]),
                        saved: false
                    })
                    if (parts[0] === '*') root.connectedSsid = parts[1]
                }
            }
            networks = list
            fetchSavedConnections()
        }
        nmcliScanProc.run(["nmcli", "-t", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list"])
    }

    // Cross-references the scanned network list against nmcli's saved
    // connection profiles so the UI knows which entries can be "forgotten".
    // Chained after scanNetworks() on the same process rather than run in
    // parallel, since nmcliScanProc only has one callback slot at a time.
    function fetchSavedConnections() {
        nmcliScanProc.callback = function(code, out) {
            if (code !== 0) return
            var saved = {}
            var lines = out.trim().split('\n')
            for (var i = 0; i < lines.length; i++) {
                if (!lines[i]) continue
                var parts = splitNmcliFields(lines[i])
                if (parts.length >= 2 && parts[1] === '802-11-wireless') {
                    saved[parts[0]] = true
                }
            }
            var updated = []
            for (var j = 0; j < root.networks.length; j++) {
                var n = root.networks[j]
                updated.push({
                    inUse: n.inUse,
                    ssid: n.ssid,
                    security: n.security,
                    signal: n.signal,
                    saved: !!saved[n.ssid]
                })
            }
            root.networks = updated
        }
        nmcliScanProc.run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"])
    }

    function toggleWifi() {
        var turningOn = !wifiEnabled
        nmcliActionProc.callback = function(code, out) {
            if (code !== 0) {
                // Revert the optimistic UI flip below since the toggle failed.
                root.wifiEnabled = !turningOn
                showStatus("Failed to turn WiFi " + (turningOn ? "on" : "off"))
            } else {
                showStatus("WiFi turned " + (turningOn ? "on" : "off"))
                if (turningOn) scanNetworks()
            }
        }
        nmcliActionProc.run(["nmcli", "radio", "wifi", turningOn ? "on" : "off"])
        wifiEnabled = turningOn
    }

    // Entry point used by the network list: opens a password prompt for
    // secured networks, connects immediately for open ones.
    function requestConnect(ssid, security) {
        var isOpen = !security || security === "" || security === "--"
        if (isOpen) {
            doConnect(ssid, "")
        } else {
            root.pendingSsid = ssid
            root.passwordDialogVisible = true
        }
    }

    function doConnect(ssid, password) {
        root.connecting = true
        showStatus("Connecting to " + ssid + "\u2026", false)

        var args = ["nmcli", "device", "wifi", "connect", ssid]
        if (password) args = args.concat(["password", password])

        nmcliActionProc.callback = function(code, out) {
            root.connecting = false
            if (code === 0) {
                showStatus("Connected to " + ssid)
                root.connectedSsid = ssid
            } else {
                // Most common cause is a wrong password; nmcli's own error
                // text ends up in stdout/stderr but we keep the user-facing
                // message simple and non-technical.
                showStatus("Couldn't connect to " + ssid + " (check password?)")
            }
            scanNetworks()
        }
        nmcliActionProc.run(args)
    }

    function submitPassword(password) {
        var ssid = root.pendingSsid
        root.passwordDialogVisible = false
        root.pendingSsid = ""
        doConnect(ssid, password)
    }

    function cancelPasswordDialog() {
        root.passwordDialogVisible = false
        root.pendingSsid = ""
    }

    // Forget-network state: tap-to-confirm since deleting a saved profile
    // can't be undone. First tap arms it, a second tap within the window
    // confirms; anything else (timeout, tapping elsewhere) disarms it.
    property string pendingForgetSsid: ""

    Timer {
        id: forgetConfirmTimer
        interval: 2500
        onTriggered: root.pendingForgetSsid = ""
    }

    function requestForget(ssid) {
        if (root.pendingForgetSsid === ssid) {
            forgetConfirmTimer.stop()
            root.pendingForgetSsid = ""
            doForget(ssid)
        } else {
            root.pendingForgetSsid = ssid
            forgetConfirmTimer.restart()
        }
    }

    function doForget(ssid) {
        showStatus("Forgetting " + ssid + "\u2026", false)
        nmcliActionProc.callback = function(code, out) {
            if (code === 0) {
                showStatus("Forgot " + ssid)
                if (root.connectedSsid === ssid) root.connectedSsid = ""
            } else {
                showStatus("Failed to forget " + ssid)
            }
            scanNetworks()
        }
        nmcliActionProc.run(["nmcli", "connection", "delete", "id", ssid])
    }

    function disconnectCurrent() {
        var ssid = root.connectedSsid
        if (!ssid) return
        showStatus("Disconnecting\u2026", false)
        // Bring the connection down by its id rather than assuming a fixed
        // interface name like "wlan0", which breaks on many systems.
        nmcliActionProc.callback = function(code, out) {
            if (code === 0) {
                showStatus("Disconnected")
                root.connectedSsid = ""
            } else {
                showStatus("Failed to disconnect")
            }
            scanNetworks()
        }
        nmcliActionProc.run(["nmcli", "connection", "down", "id", ssid])
    }

    function showStatus(message, autoClear) {
        root.statusMessage = message
        statusClearTimer.stop()
        if (autoClear !== false) statusClearTimer.start()
    }

    // nmcli's terse (-t) output escapes literal ':' as '\:' and '\' as '\\'
    // within a field (e.g. an SSID that contains a colon). A plain
    // line.split(':') breaks on that escaped colon too, shifting every
    // field after it by one. This splits only on *unescaped* colons and
    // un-escapes the result.
    function splitNmcliFields(line) {
        var fields = []
        var current = ""
        for (var i = 0; i < line.length; i++) {
            var ch = line[i]
            if (ch === '\\' && i + 1 < line.length) {
                current += line[i + 1]
                i++
            } else if (ch === ':') {
                fields.push(current)
                current = ""
            } else {
                current += ch
            }
        }
        fields.push(current)
        return fields
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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.border.color = "#ebdbb2"
                            onExited: parent.border.color = modelData.inUse ? "#7c6f64" : "#504945"
                            onClicked: {
                                if (modelData.inUse) root.disconnectCurrent()
                                else root.requestConnect(modelData.ssid, modelData.security)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 8
                            Text {
                                text: (modelData.security && modelData.security !== "--" ? "\uf023  " : "") +
                                      (modelData.ssid ? modelData.ssid : "")
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
                            Text {
                                // Forget button: only for saved, not-currently-in-use
                                // networks. Tap once to arm, again to confirm.
                                visible: modelData.saved && !modelData.inUse
                                text: root.pendingForgetSsid === modelData.ssid ? "Sure?" : "\uf1f8"
                                color: root.pendingForgetSsid === modelData.ssid ? "#fb4934" : "#928374"
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize - 2

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.requestForget(modelData.ssid)
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.statusMessage !== ""
                    text: root.statusMessage
                    color: "#fabd2f"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize - 2
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
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

        // Password prompt, shown over the panel when connecting to a
        // secured network. This is the piece that was missing entirely
        // before: secured networks previously always connected with an
        // empty password and failed silently.
        Rectangle {
            id: passwordDialog
            visible: root.passwordDialogVisible
            anchors.fill: parent
            color: "#000000AA"

            MouseArea {
                // Swallow clicks so they don't fall through to the network list.
                anchors.fill: parent
                onClicked: {}
            }

            Rectangle {
                width: 300
                height: 170
                anchors.centerIn: parent
                radius: 12
                color: "#282828"
                border.width: 2
                border.color: "#7c6f64"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "Password for \"" + root.pendingSsid + "\""
                        color: "#ebdbb2"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 8
                        color: "#3c3836"
                        border.width: 1
                        border.color: passwordInput.activeFocus ? "#ebdbb2" : "#504945"

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#ebdbb2"
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            echoMode: TextInput.Password
                            focus: root.passwordDialogVisible
                            selectByMouse: true
                            Keys.onReturnPressed: root.submitPassword(text)
                            Keys.onEnterPressed: root.submitPassword(text)
                            Keys.onEscapePressed: root.cancelPasswordDialog()
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 15
                            color: "#504945"
                            border.width: 2
                            border.color: "#7c6f64"
                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: "#ebdbb2"
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelPasswordDialog()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 15
                            color: "#83a598"
                            border.width: 2
                            border.color: "#7c6f64"
                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: "#282828"
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitPassword(passwordInput.text)
                            }
                        }
                    }
                }
            }

            onVisibleChanged: if (visible) passwordInput.text = ""
        }
    }
}