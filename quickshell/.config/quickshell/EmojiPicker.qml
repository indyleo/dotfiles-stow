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
    // AppLauncher/ClipboardController, rather than the old "emoji-picker"
    // directory this file used before.
    readonly property string cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell-emoji"
    readonly property string emojiFile: cacheDir + "/emoji-test.txt"
    readonly property string emojiSourceUrl: "https://unicode.org/Public/emoji/latest/emoji-test.txt"

    property var allEmojis: []      // every fully-qualified entry, including skin-tone variants
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

    // Parses Unicode's official emoji-test.txt format:
    //   1F600                    ; fully-qualified     # 😀 E1.0 grinning face
    //   1F44D 1F3FB              ; fully-qualified     # 👍🏻 E1.0 thumbs up: light skin tone
    // Only "fully-qualified" entries are kept (skips "component" - lone
    // skin-tone modifier characters - and "minimally-qualified"/
    // "unqualified" duplicates). Skin-tone variants share a "baseName"
    // with their default (toneless) entry, which the tone selector below
    // uses to group them.
    function parseEmojiTestFile(content) {
        var toneRe = /^(.*): (light|medium-light|medium|medium-dark|dark) skin tone$/
        var lines = content.split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line === "" || line[0] === "#") continue

            var semi = line.indexOf(";")
            if (semi === -1) continue
            var rest = line.substring(semi + 1)

            var hash = rest.indexOf("#")
            if (hash === -1) continue
            var status = rest.substring(0, hash).trim()
            if (status !== "fully-qualified") continue

            var afterHash = rest.substring(hash + 1).trim()
            var spaceIdx = afterHash.indexOf(" ")
            if (spaceIdx === -1) continue
            var glyph = afterHash.substring(0, spaceIdx)
            var afterGlyph = afterHash.substring(spaceIdx + 1).trim() // "E1.0 grinning face"

            var m = afterGlyph.match(/^E[\d.]+\s+(.+)$/)
            if (!m) continue
            var name = m[1]

            var toneMatch = name.match(toneRe)
            result.push({
                emoji: glyph,
                name: name,
                baseName: toneMatch ? toneMatch[1] : name,
                tone: toneMatch ? toneMatch[2] : null
            })
        }
        return result
    }

    FileView {
        id: emojiFileView
        path: root.emojiFile
        onLoaded: {
            var content = text()
            if (content !== "") root.allEmojis = root.parseEmojiTestFile(content)
        }
    }

    // baseName -> { default: emoji, light: emoji, "medium-light": emoji, ... }
    readonly property var toneMap: {
        var map = {}
        for (var i = 0; i < allEmojis.length; i++) {
            var e = allEmojis[i]
            if (!map[e.baseName]) map[e.baseName] = {}
            map[e.baseName][e.tone || "default"] = e.emoji
        }
        return map
    }

    // Only the toneless/default entry of each emoji is shown in the main
    // list; tone variants (if any) are reachable via the per-row selector.
    readonly property var displayEmojis: allEmojis.filter(function(e) { return e.tone === null })

    readonly property var filteredEmojis: {
        if (searchText === "") return displayEmojis
        var q = searchText.toLowerCase()
        return displayEmojis.filter(function(e) {
            return e.name.toLowerCase().includes(q) || e.emoji === searchText
        })
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
                emojiFileView.reload()
            } else {
                root.updateStatus = "Update failed"
                console.warn("[EmojiPicker] fetch failed:", code, fetchProc.stderr.text)
            }
        }
    }

    function updateEmojiData() {
        root.updating = true
        root.updateStatus = ""
        fetchProc.command = ["sh", "-c",
            "mkdir -p \"$1\" && curl -sL --max-time 20 -o \"$2\" \"$3\"",
            "fetch-emoji", root.cacheDir, root.emojiFile, root.emojiSourceUrl
        ]
        fetchProc.running = false
        fetchProc.running = true
    }

    Process {
        id: checkExistsProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "no") root.updateEmojiData()
            }
        }
    }

    Component.onCompleted: {
        // Auto-fetch on first run only, if the cache is missing or empty.
        checkExistsProc.command = ["sh", "-c", "[ -s \"$1\" ] && echo yes || echo no", "check", root.emojiFile]
        checkExistsProc.running = true
    }

    Process {
        id: copyProc
        onExited: (code, status) => {
            if (code === 0) root.active = false
        }
    }

    function copyEmoji(emoji) {
        copyProc.command = ["wl-copy", "--", emoji]
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
                    text: "Emoji Picker"
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
                        onClicked: root.updateEmojiData()
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
                model: root.filteredEmojis

                Text {
                    visible: root.allEmojis.length === 0
                    anchors.centerIn: parent
                    text: root.updating ? "Downloading emoji data…" : "No emoji data yet - tap Update"
                    color: "#bdae93"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                }

                delegate: Rectangle {
                    id: emojiDelegate
                    required property var modelData
                    readonly property var variants: root.toneMap[modelData.baseName] || {}
                    readonly property bool hasTones: Object.keys(variants).length > 1
                    property bool toneMenuOpen: false

                    width: ListView.view.width
                    height: toneMenuOpen ? 82 : 40
                    radius: 10
                    color: cal2
                    border.width: 1
                    border.color: cal3
                    clip: true

                    Behavior on height { NumberAnimation { duration: 100 } }

                    // Whole-row click = copy the default emoji. Declared
                    // first (z: -1) so the tone-toggle icon and swatch
                    // buttons below, declared after, sit on top and get
                    // their own clicks instead of the row swallowing them.
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.border.color = cal14
                        onExited: parent.border.color = cal3
                        hoverEnabled: true
                        onClicked: root.copyEmoji(emojiDelegate.modelData.emoji)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: emojiDelegate.modelData.emoji
                                color: cal6
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize + 4
                            }
                            Text {
                                text: emojiDelegate.modelData.name
                                color: cal6
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: emojiDelegate.hasTones
                                text: "\uf1de"
                                color: emojiDelegate.toneMenuOpen ? cal14 : cal3
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: emojiDelegate.toneMenuOpen = !emojiDelegate.toneMenuOpen
                                }
                            }
                        }

                        RowLayout {
                            visible: emojiDelegate.toneMenuOpen
                            spacing: 8
                            Repeater {
                                model: ["default", "light", "medium-light", "medium", "medium-dark", "dark"].filter(function(t) { return emojiDelegate.variants[t] })
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 32; height: 32; radius: 8
                                    color: cal0
                                    border.width: 1
                                    border.color: cal3
                                    Text {
                                        anchors.centerIn: parent
                                        text: emojiDelegate.variants[modelData]
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 2
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.border.color = cal14
                                        onExited: parent.border.color = cal3
                                        onClicked: root.copyEmoji(emojiDelegate.variants[modelData])
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
