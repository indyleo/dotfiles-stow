import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

// WiFi panel. Mirrors the flow of the `wifi` menu script:
//   * scan results are deduped by SSID (strongest AP wins); blank/hidden SSIDs are skipped
//   * the real radio state is read from nmcli (not assumed "on"); when it's off the
//     panel only offers the toggle
//   * clicking a network: connected -> disconnect, saved -> bring the saved profile
//     up (no password prompt, with the stale interface-name retry), open -> connect,
//     otherwise ask for a password
//   * footer has Disconnect and Manual / Hidden SSID entry
//   * "Forget" (tap twice) stays as a GUI-only extra
Item {
    id: root

    property bool active: false
    property var networks: []
    property bool wifiEnabled: true
    property string connectedSsid: ""
    property string wifiDevice: ""
    property bool hasScanned: false

    // User-visible feedback for the last action (connect/disconnect/toggle).
    property string statusMessage: ""
    // True while any action (connect/disconnect/toggle/forget) is in flight.
    property bool connecting: false

    // "" (closed) | "password" (secured network) | "manual" (typed SSID, may be hidden)
    property string dialogMode: ""
    property string pendingSsid: ""

    // Font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize

    // Forget-network state: tap-to-confirm since deleting a saved profile
    // can't be undone. First tap arms it, a second tap within the window
    // confirms; anything else (timeout, tapping elsewhere) disarms it.
    property string pendingForgetSsid: ""

    // Last list we assigned, so an unchanged scan doesn't reset the ListView
    // (which would jump the scroll position every poll).
    property string lastNetworksKey: ""

    onActiveChanged: {
        if (active) {
            root.hasScanned = false
            scanNetworks()
        } else {
            root.cancelDialog()
            root.pendingForgetSsid = ""
        }
    }

    // ------------------------------------------------------------
    // Process plumbing
    //
    // Process.stdout is a parser object, not a string, and is null (output
    // discarded) unless a StdioCollector is attached. Cmd wraps that up:
    // callback(exitCode, stdoutText, stderrText) fires once the process has
    // exited and its output is available.
    // ------------------------------------------------------------

    component Cmd: Item {
        id: cmd
        property var callback: null
        property int lastCode: 0
        readonly property bool busy: proc.running || settle.running

        function run(args) {
            proc.command = args
            proc.running = false
            proc.running = true
        }

        Process {
            id: proc
            stdout: StdioCollector { id: outText }
            stderr: StdioCollector { id: errText }
            onExited: (exitCode, exitStatus) => {
                cmd.lastCode = exitCode
                settle.restart()
            }
        }

        // exited() can arrive before the collectors publish their text, so
        // give them a moment instead of relying on signal order.
        Timer {
            id: settle
            interval: 20
            onTriggered: {
                var cb = cmd.callback
                cmd.callback = null
                if (cb) cb(cmd.lastCode, outText.text, errText.text)
            }
        }
    }

    // Dedicated processes for periodic scanning and for user-initiated
    // actions, so an action can never drop an in-flight scan callback or
    // vice versa.
    Cmd { id: scanCmd }
    Cmd { id: actionCmd }

    Timer {
        interval: 3000
        running: root.active
        repeat: true
        onTriggered: root.scanNetworks()
    }

    // Clears a transient status message after a few seconds so it doesn't
    // linger forever on screen.
    Timer {
        id: statusClearTimer
        interval: 4000
        onTriggered: root.statusMessage = ""
    }

    Timer {
        id: forgetConfirmTimer
        interval: 2500
        onTriggered: root.pendingForgetSsid = ""
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: root.focusDialog()
    }

    // ------------------------------------------------------------
    // Scanning: one shell run gathers everything the script gathers
    // (radio state, wifi device, saved profiles, scan list).
    // ------------------------------------------------------------

    readonly property string scanScript:
        "echo @@radio; nmcli radio wifi;" +
        "echo @@dev; nmcli -t -f DEVICE,TYPE device;" +
        "echo @@saved; nmcli -t -f NAME,TYPE connection show;" +
        "echo @@scan; nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL device wifi list 2>/dev/null"

    function scanNetworks() {
        if (root.connecting || scanCmd.busy) return
        scanCmd.callback = function(code, out, err) {
            // An action started while this scan was running; its own
            // completion triggers a fresh scan.
            if (root.connecting) return
            root.applyScan(out)
        }
        scanCmd.run(["sh", "-c", root.scanScript, "wifi-scan"])
    }

    function applyScan(text) {
        var section = ""
        var radio = ""
        var dev = ""
        var saved = {}
        var byName = {}
        var connected = ""
        var f
        var lines = text.split("\n")

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("@@") === 0) { section = line.substring(2); continue }
            if (line === "") continue

            if (section === "radio") {
                radio = line.trim()
            } else if (section === "dev") {
                f = splitNmcliFields(line)
                if (dev === "" && f.length >= 2 && f[1] === "wifi") dev = f[0]
            } else if (section === "saved") {
                f = splitNmcliFields(line)
                if (f.length >= 2 && f[1] === "802-11-wireless") saved["s:" + f[0]] = true
            } else if (section === "scan") {
                // IN-USE:SSID:SECURITY:SIGNAL. Don't trim the line: IN-USE is
                // a blank for networks we're not on.
                f = splitNmcliFields(line)
                if (f.length < 4 || f[1] === "") continue
                var ssid = f[1]
                var sig = parseInt(f[3])
                if (isNaN(sig)) sig = 0
                var inUse = f[0] === "*"
                if (inUse) connected = ssid

                var key = "s:" + ssid
                var cur = byName[key]
                if (!cur) {
                    byName[key] = { ssid: ssid, security: f[2], signal: sig, inUse: inUse }
                } else {
                    if (inUse) cur.inUse = true
                    if (sig > cur.signal) { cur.signal = sig; cur.security = f[2] }
                }
            }
        }

        var list = []
        var keys = Object.keys(byName)
        for (var k = 0; k < keys.length; k++) {
            var n = byName[keys[k]]
            n.saved = !!saved[keys[k]]
            list.push(n)
        }
        // Connected network first, then strongest signal.
        list.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            if (a.signal !== b.signal) return b.signal - a.signal
            return a.ssid < b.ssid ? -1 : (a.ssid > b.ssid ? 1 : 0)
        })

        root.wifiEnabled = radio !== "disabled"
        root.wifiDevice = dev
        root.connectedSsid = root.wifiEnabled ? connected : ""
        if (!root.wifiEnabled) list = []
        root.hasScanned = true

        var listKey = JSON.stringify(list)
        if (listKey !== root.lastNetworksKey) {
            root.lastNetworksKey = listKey
            root.networks = list
        }
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

    // ------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------

    function showStatus(message, autoClear) {
        root.statusMessage = message
        statusClearTimer.stop()
        if (autoClear !== false) statusClearTimer.start()
    }

    function toggleWifi() {
        if (root.connecting) return
        var turningOn = !root.wifiEnabled
        root.connecting = true
        // Optimistic flip, reverted below if nmcli fails.
        root.wifiEnabled = turningOn
        if (!turningOn) {
            root.networks = []
            root.lastNetworksKey = ""
            root.connectedSsid = ""
        }
        actionCmd.callback = function(code, out, err) {
            root.connecting = false
            if (code === 0) {
                showStatus("WiFi turned " + (turningOn ? "on" : "off"))
            } else {
                root.wifiEnabled = !turningOn
                showStatus("Failed to turn WiFi " + (turningOn ? "on" : "off"))
            }
            scanNetworks()
        }
        actionCmd.run(["nmcli", "radio", "wifi", turningOn ? "on" : "off"])
    }

    // Entry point used by the network list, same decision tree as the script.
    function activate(net) {
        if (root.connecting) return
        if (net.inUse) {
            disconnectCurrent()
        } else if (net.saved) {
            connectSaved(net.ssid)
        } else if (!net.security || net.security === "--") {
            connectNew(net.ssid, "", false)
        } else {
            openDialog("password", net.ssid)
        }
    }

    function finishConnect(ssid, ok, failMessage) {
        root.connecting = false
        if (ok) {
            showStatus("Connected to " + ssid)
            root.connectedSsid = ssid
        } else {
            showStatus(failMessage)
        }
        scanNetworks()
    }

    // Saved profile: connect immediately, no password prompt.
    function connectSaved(ssid) {
        root.connecting = true
        showStatus("Connecting to " + ssid + "\u2026", false)

        var up = ["nmcli", "connection", "up", "id", ssid]
        if (root.wifiDevice !== "") up = up.concat(["ifname", root.wifiDevice])
        var failMessage = "Failed to connect to " + ssid

        actionCmd.callback = function(code, out, err) {
            var msg = (out + err).toLowerCase()
            if (code !== 0 && msg.indexOf("interface name") !== -1) {
                // Stale connection.interface-name binding on the saved
                // profile: clear it and retry once.
                actionCmd.callback = function() {
                    actionCmd.callback = function(code2) {
                        root.finishConnect(ssid, code2 === 0, failMessage)
                    }
                    actionCmd.run(up)
                }
                actionCmd.run(["nmcli", "connection", "modify", "id", ssid, "connection.interface-name", ""])
                return
            }
            root.finishConnect(ssid, code === 0, failMessage)
        }
        actionCmd.run(up)
    }

    // No saved profile. "hidden" is for SSIDs that don't broadcast; without
    // it nmcli only looks in the scan list and gives up.
    function connectNew(ssid, password, hidden) {
        root.connecting = true
        showStatus("Connecting to " + ssid + "\u2026", false)

        var args = ["nmcli", "device", "wifi", "connect", ssid]
        if (password) args = args.concat(["password", password])
        if (hidden) args = args.concat(["hidden", "yes"])

        actionCmd.callback = function(code, out, err) {
            // Most common cause is a wrong password; keep the message simple.
            root.finishConnect(ssid, code === 0, "Couldn't connect to " + ssid + " (check password?)")
        }
        actionCmd.run(args)
    }

    function disconnectCurrent() {
        if (root.connecting || root.connectedSsid === "") return
        var ssid = root.connectedSsid
        root.connecting = true
        showStatus("Disconnecting\u2026", false)

        // Same as the script: disconnect the wifi device rather than looking
        // a profile up by SSID (profile names don't always match).
        var args = root.wifiDevice !== ""
            ? ["nmcli", "device", "disconnect", root.wifiDevice]
            : ["nmcli", "connection", "down", "id", ssid]

        actionCmd.callback = function(code, out, err) {
            root.connecting = false
            if (code === 0) {
                showStatus(ssid === "" ? "Disconnected" : "Disconnected from " + ssid)
                root.connectedSsid = ""
            } else {
                showStatus("Failed to disconnect")
            }
            scanNetworks()
        }
        actionCmd.run(args)
    }

    function requestForget(ssid) {
        if (root.connecting) return
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
        root.connecting = true
        showStatus("Forgetting " + ssid + "\u2026", false)
        actionCmd.callback = function(code, out, err) {
            root.connecting = false
            if (code === 0) {
                showStatus("Forgot " + ssid)
                if (root.connectedSsid === ssid) root.connectedSsid = ""
            } else {
                showStatus("Failed to forget " + ssid)
            }
            scanNetworks()
        }
        actionCmd.run(["nmcli", "connection", "delete", "id", ssid])
    }

    // ------------------------------------------------------------
    // Dialog (password for a secured network / manual + hidden SSID)
    // ------------------------------------------------------------

    function openDialog(mode, ssid) {
        ssidField.input.text = ""
        passwordField.input.text = ""
        root.pendingSsid = ssid || ""
        root.dialogMode = mode
        focusTimer.restart()
    }

    function focusDialog() {
        if (root.dialogMode === "manual") ssidField.input.forceActiveFocus()
        else if (root.dialogMode === "password") passwordField.input.forceActiveFocus()
    }

    function cancelDialog() {
        root.dialogMode = ""
        root.pendingSsid = ""
        ssidField.input.text = ""
        passwordField.input.text = ""
    }

    function submitDialog() {
        var password = passwordField.input.text
        if (root.dialogMode === "manual") {
            var ssid = ssidField.input.text.trim()
            if (ssid === "") return
            cancelDialog()
            // Blank password = open network. Always "hidden": the SSID was typed by hand.
            connectNew(ssid, password, true)
        } else if (root.dialogMode === "password") {
            // Same as the script: an empty password is a cancel.
            if (password === "") return
            var target = root.pendingSsid
            cancelDialog()
            connectNew(target, password, false)
        }
    }

    // ------------------------------------------------------------
    // Small reusable pieces (Theme is a singleton, so these don't need `root`)
    // ------------------------------------------------------------

    component PillButton: Rectangle {
        id: btn
        property string label: ""
        property color fill: "#504945"
        property color hoverFill: "#7c6f64"
        property color textColor: "#ebdbb2"
        property bool bold: false
        property bool dimmed: false
        signal clicked()

        Layout.preferredHeight: 30
        radius: 15
        color: (btnMouse.containsMouse && !btn.dimmed) ? btn.hoverFill : btn.fill
        border.width: 2
        border.color: (btnMouse.containsMouse && !btn.dimmed) ? "#ebdbb2" : "#7c6f64"
        opacity: btn.dimmed ? 0.4 : 1.0

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.textColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: btn.bold
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.dimmed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!btn.dimmed) btn.clicked()
        }
    }

    component Field: Rectangle {
        id: field
        property alias input: textInput
        property string placeholder: ""
        property bool secret: false
        signal accepted()
        signal tabbed()
        signal escaped()

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 8
        color: "#3c3836"
        border.width: 1
        border.color: textInput.activeFocus ? "#ebdbb2" : "#504945"

        TextInput {
            id: textInput
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: "#ebdbb2"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            echoMode: field.secret ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            clip: true
            Keys.onReturnPressed: field.accepted()
            Keys.onEnterPressed: field.accepted()
            Keys.onTabPressed: field.tabbed()
            Keys.onEscapePressed: field.escaped()
        }

        Text {
            anchors.fill: textInput
            verticalAlignment: Text.AlignVCenter
            visible: textInput.text === ""
            text: field.placeholder
            color: "#928374"
            font: textInput.font
        }
    }

    // ------------------------------------------------------------
    // UI
    // ------------------------------------------------------------

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
            width: 400
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
                        text: root.wifiEnabled ? "WiFi" : "WiFi (disabled)"
                        color: "#ebdbb2"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize + 4
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: wifiToggle
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 30
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

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        anchors.fill: parent
                        clip: true
                        visible: root.wifiEnabled
                        model: root.networks

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool isOpen: !modelData.security || modelData.security === "--"

                            width: ListView.view.width
                            height: 40
                            radius: 8
                            color: modelData.inUse ? "#3c3836" : "#504945"
                            border.width: 1
                            border.color: rowMouse.containsMouse ? "#ebdbb2"
                                        : (modelData.inUse ? "#7c6f64" : "#504945")

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.activate(row.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Connected marker, same as the script's leading arrow
                                Text {
                                    Layout.preferredWidth: 12
                                    text: row.modelData.inUse ? "\u25B6" : ""
                                    color: "#83a598"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
                                }
                                Text {
                                    text: row.modelData.ssid
                                    color: "#ebdbb2"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: row.isOpen ? "open" : row.modelData.security
                                    color: "#928374"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 3
                                }
                                Text {
                                    text: row.modelData.signal + "%"
                                    color: "#fabd2f"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
                                }
                                Text {
                                    // Saved-profile marker
                                    visible: row.modelData.saved
                                    text: "\uf0c7"
                                    color: "#928374"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2
                                }
                                Text {
                                    // Forget button: only for saved, not-currently-in-use
                                    // networks. Tap once to arm, again to confirm.
                                    visible: row.modelData.saved && !row.modelData.inUse
                                    text: root.pendingForgetSsid === row.modelData.ssid ? "Sure?" : "\uf1f8"
                                    color: root.pendingForgetSsid === row.modelData.ssid ? "#fb4934" : "#928374"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 2

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.requestForget(row.modelData.ssid)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.wifiEnabled || root.networks.length === 0
                        text: !root.wifiEnabled ? "WiFi is disabled"
                            : (root.hasScanned ? "No networks found" : "Scanning\u2026")
                        color: "#928374"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PillButton {
                        Layout.fillWidth: true
                        label: "Disconnect"
                        dimmed: root.connectedSsid === "" || root.connecting
                        onClicked: root.disconnectCurrent()
                    }
                    PillButton {
                        Layout.fillWidth: true
                        label: "Manual / Hidden"
                        dimmed: !root.wifiEnabled || root.connecting
                        onClicked: root.openDialog("manual", "")
                    }
                    PillButton {
                        Layout.fillWidth: true
                        label: "Close"
                        onClicked: root.active = false
                    }
                }
            }
        }

        // Password / manual-SSID dialog, shown over the panel.
        Rectangle {
            id: dialogOverlay
            visible: root.dialogMode !== ""
            anchors.fill: parent
            color: "#000000AA"

            MouseArea {
                // Swallow clicks so they don't fall through to the network list.
                anchors.fill: parent
                onClicked: {}
            }

            Rectangle {
                width: 320
                height: root.dialogMode === "manual" ? 230 : 170
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
                        text: root.dialogMode === "manual"
                            ? "Manual / Hidden SSID"
                            : "Password for \"" + root.pendingSsid + "\""
                        color: "#ebdbb2"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Field {
                        id: ssidField
                        visible: root.dialogMode === "manual"
                        placeholder: "SSID"
                        onAccepted: passwordField.input.forceActiveFocus()
                        onTabbed: passwordField.input.forceActiveFocus()
                        onEscaped: root.cancelDialog()
                    }

                    Field {
                        id: passwordField
                        secret: true
                        placeholder: root.dialogMode === "manual" ? "Password (blank if open)" : "Password"
                        onAccepted: root.submitDialog()
                        onEscaped: root.cancelDialog()
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        PillButton {
                            Layout.fillWidth: true
                            label: "Cancel"
                            onClicked: root.cancelDialog()
                        }
                        PillButton {
                            Layout.fillWidth: true
                            label: "Connect"
                            fill: "#83a598"
                            hoverFill: "#83a598"
                            textColor: "#282828"
                            bold: true
                            onClicked: root.submitDialog()
                        }
                    }
                }
            }
        }
    }
}
