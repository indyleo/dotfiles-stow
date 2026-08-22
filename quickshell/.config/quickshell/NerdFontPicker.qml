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

    // Cache dir follows the same "quickshell-<name>" convention used by
    // AppLauncher/ClipboardController/EmojiPicker, rather than the old
    // "nerdfont-picker" directory this file used before.
    readonly property string cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell-nerdfont"
    readonly property string nerdfontFile: cacheDir + "/nerd-fonts-generated.css"
    readonly property string nerdfontSourceUrl: "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/css/nerd-fonts-generated.css"

    property var allIcons: []
    property string searchText: ""

    property bool updating: false
    property string updateStatus: ""

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

    // Parses rules like:
    //   .nf-fa-github:before { content: "\f09b"; }
    // out of the generated CSS, regardless of exact whitespace/formatting.
    function parseNerdFontCss(content) {
        var re = /\.nf-([a-zA-Z0-9_-]+):before\s*\{\s*content:\s*"\\([0-9a-fA-F]+)"/g
        var result = []
        var m
        while ((m = re.exec(content)) !== null) {
            var codepoint = parseInt(m[2], 16)
            result.push({ name: m[1], glyph: String.fromCodePoint(codepoint) })
        }
        return result
    }

    FileView {
        id: iconFileView
        path: root.nerdfontFile
        onLoaded: {
            var content = text()
            if (content !== "") root.allIcons = root.parseNerdFontCss(content)
        }
    }

    readonly property var filteredIcons: {
        if (searchText === "") return allIcons
        var q = searchText.toLowerCase()
        return allIcons.filter(function(e) { return e.name.toLowerCase().includes(q) })
    }

    // ------------------------------------------------------------
    // Fetch / cache update
    // ------------------------------------------------------------

    Process {
        id: fetchProc
        stderr: StdioCollector {}
        onExited: (code, status) => {
            root.updating = false
            if (code === 0) {
                root.updateStatus = "Updated"
                iconFileView.reload()
            } else {
                root.updateStatus = "Update failed"
                console.warn("[NerdFontPicker] fetch failed:", code, fetchProc.stderr.text)
            }
        }
    }

    function updateIconData() {
        root.updating = true
        root.updateStatus = ""
        fetchProc.command = ["sh", "-c",
            "mkdir -p \"$1\" && curl -sL --max-time 20 -o \"$2\" \"$3\"",
            "fetch-nerdfont", root.cacheDir, root.nerdfontFile, root.nerdfontSourceUrl
        ]
        fetchProc.running = false
        fetchProc.running = true
    }

    Process {
        id: checkExistsProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "no") root.updateIconData()
            }
        }
    }

    Component.onCompleted: {
        // Auto-fetch on first run only, if the cache is missing or empty.
        checkExistsProc.command = ["sh", "-c", "[ -s \"$1\" ] && echo yes || echo no", "check", root.nerdfontFile]
        checkExistsProc.running = true
    }

    Process {
        id: copyProc
        onExited: (code, status) => {
            if (code === 0) root.active = false
        }
    }

    function copyIcon(icon) {
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

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Nerd Font Icon Picker"
                    color: cal6
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 4
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: root.updateStatus !== ""
                    text: root.updateStatus
                    color: root.updateStatus === "Updated" ? "#b8bb26" : "#fb4934"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize - 2
                }
                Rectangle {
                    Layout.preferredWidth: updateText.implicitWidth + 20
                    Layout.preferredHeight: 26
                    radius: 13
                    color: cal2
                    border.width: 1
                    border.color: cal3
                    Text {
                        id: updateText
                        anchors.centerIn: parent
                        text: root.updating ? "Updating…" : "\uf021  Update"
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.updating
												hoverEnabled: true
																								onEntered: {
                          parent.color = cal3
													parent.border.color = cal14
												}
												onExited: {
													parent.color = cal2
													parent.border.color = cal3
												}
                        onClicked: root.updateIconData()
                    }
                }
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

                Text {
                    visible: root.allIcons.length === 0
                    anchors.centerIn: parent
                    text: root.updating ? "Downloading icon data…" : "No icon data yet - tap Update"
                    color: "#bdae93"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                }

                delegate: Rectangle {
                    id: iconDelegate
                    required property var modelData
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
                            text: iconDelegate.modelData.glyph
                            color: cal6
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize + 4
                        }

                        Text {
                            text: iconDelegate.modelData.name
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
                        onClicked: root.copyIcon(iconDelegate.modelData.glyph)
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
