import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts
import QtCore

// A dmenu_run-style launcher: type a full command line (with args, pipes,
// whatever `sh -c` accepts) and Enter runs exactly what's typed. Below the
// input it suggests your recent commands and everything executable on
// $PATH, ranked by how often/recently you've used them, purely to help you
// get there faster - they never change what Enter actually runs.
PanelWindow {
    id: root

    property bool active: false
    visible: active

    property var executables: []
    property var usage: ({})
    property var history: []
    property string searchText: ""
    property int selectedIndex: 0

    // Colors/font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize
    readonly property color cal0: Theme.cal0
    readonly property color cal2: Theme.cal2
    readonly property color cal3: Theme.cal3
    readonly property color cal6: Theme.cal6
    readonly property color cal14: Theme.cal14

    // Shares the same cache dir as AppLauncher but its own file, so the two
    // pickers' frecency data never collide.
    readonly property string cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell-launcher"
    readonly property string stateFile: cacheDir + "/cmd-launcher.json"

    screen: Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { top: true; bottom: true; left: true; right: true }

    // ------------------------------------------------------------
    // $PATH discovery
    // ------------------------------------------------------------

    // NUL-delimited so executable names containing spaces survive. Dedupes
    // across $PATH dirs with a SEEN scratch file (same trick AppLauncher
    // uses) rather than an associative array, since dash's `sh` doesn't
    // have those.
    readonly property string listScript: [
        "SEEN=$(mktemp)",
        "OLDIFS=$IFS",
        "IFS=':'",
        "for d in $PATH; do",
        "  IFS=\"$OLDIFS\"",
        "  [ -n \"$d\" ] && [ -d \"$d\" ] || continue",
        "  for f in \"$d\"/*; do",
        "    [ -f \"$f\" ] && [ -x \"$f\" ] || continue",
        "    b=$(basename \"$f\")",
        "    grep -qxF \"$b\" \"$SEEN\" 2>/dev/null && continue",
        "    echo \"$b\" >> \"$SEEN\"",
        "    printf '%s\\0' \"$b\"",
        "  done",
        "  IFS=':'",
        "done",
        "rm -f \"$SEEN\""
    ].join("\n")

    Process {
        id: listProc
        command: ["sh", "-c", root.listScript]
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[CommandLauncher] Failed to list $PATH executables:", code)
                return
            }
            root.executables = listProc.stdout.text.split("\u0000").filter(n => n !== "")
        }
    }

    function refreshExecutables() {
        listProc.running = false
        listProc.running = true
    }

    // ------------------------------------------------------------
    // State: recent commands + per-executable usage counts, both used
    // only to rank suggestions.
    // ------------------------------------------------------------

    FileView {
        id: stateFileObj
        path: root.stateFile
    }

    Process {
        id: mkdirProc
        property var callback
        onExited: (code, status) => {
            if (mkdirProc.callback) {
                var cb = mkdirProc.callback
                mkdirProc.callback = null
                cb(code)
            }
        }
    }

    function loadState() {
        try {
            var parsed = JSON.parse(stateFileObj.text())
            root.usage = (parsed && typeof parsed.usage === "object") ? parsed.usage : {}
            root.history = (parsed && Array.isArray(parsed.history)) ? parsed.history : []
        } catch (e) {
            root.usage = {}
            root.history = []
        }
    }

    function saveState() {
        var data = JSON.stringify({ usage: root.usage, history: root.history })
        mkdirProc.callback = function(code) {
            if (code === 0) {
                stateFileObj.setText(data)
            } else {
                console.warn("[CommandLauncher] Failed to create cache dir:", code)
            }
        }
        mkdirProc.command = ["mkdir", "-p", root.cacheDir]
        mkdirProc.running = false
        mkdirProc.running = true
    }

    // ------------------------------------------------------------
    // Running - always runs the literal text passed in through `sh -c`,
    // detached, so pipes/redirects/quoting/args all work exactly like a
    // real shell prompt.
    // ------------------------------------------------------------

    function runCommand(cmd) {
        var trimmed = cmd.trim()
        if (trimmed === "") return

        Quickshell.execDetached({ command: ["sh", "-c", trimmed] })

        var h = root.history.filter(function(c) { return c !== trimmed })
        h.unshift(trimmed)
        if (h.length > 50) h = h.slice(0, 50)
        root.history = h

        var firstToken = trimmed.split(/\s+/)[0]
        if (root.executables.indexOf(firstToken) !== -1) {
            var u = root.usage
            u[firstToken] = (u[firstToken] || 0) + 1
            root.usage = u
        }

        root.saveState()
        root.active = false
    }

    function runSelected() {
        root.runCommand(searchInput.text)
    }

    // Tab fills the input from the highlighted suggestion without running
    // it, so you can add arguments before pressing Enter.
    function fillFromSelection() {
        var list = root.filteredItems
        if (list.length === 0) return
        var idx = Math.max(0, Math.min(root.selectedIndex, list.length - 1))
        searchInput.text = list[idx].text
        searchInput.cursorPosition = searchInput.text.length
    }

    // ------------------------------------------------------------
    // Suggestions: matching recent commands first (most-recent-first),
    // then matching $PATH executables (prefix match, then frecency)
    // ------------------------------------------------------------

    readonly property var filteredItems: {
        var q = searchText.trim().toLowerCase()
        var seen = {}
        var results = []

        for (var i = 0; i < history.length; i++) {
            var h = history[i]
            if (q !== "" && h.toLowerCase().indexOf(q) === -1) continue
            if (seen[h]) continue
            seen[h] = true
            results.push({ text: h, isHistory: true })
        }

        var exeMatches = executables.filter(function(e) {
            if (seen[e]) return false
            if (q === "") return true
            return e.toLowerCase().indexOf(q) !== -1
        })
        exeMatches.sort(function(a, b) {
            if (q !== "") {
                var aStarts = a.toLowerCase().startsWith(q) ? 0 : 1
                var bStarts = b.toLowerCase().startsWith(q) ? 0 : 1
                if (aStarts !== bStarts) return aStarts - bStarts
            }
            var au = usage[a] || 0
            var bu = usage[b] || 0
            if (au !== bu) return bu - au
            return a.localeCompare(b)
        })
        for (var j = 0; j < exeMatches.length; j++) {
            results.push({ text: exeMatches[j], isHistory: false })
        }

        return results
    }

    onFilteredItemsChanged: {
        if (root.selectedIndex >= filteredItems.length) root.selectedIndex = Math.max(0, filteredItems.length - 1)
    }

    onActiveChanged: {
        if (active) {
            searchText = ""
            selectedIndex = 0
            refreshExecutables()
            loadState()
            focusTimer.start()
        } else {
            searchText = ""
            if (searchInput) searchInput.text = ""
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    // ------------------------------------------------------------
    // UI
    // ------------------------------------------------------------

    Rectangle {
        width: 480
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
                text: "Run"
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

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Type a command..."
                    color: cal3
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    visible: searchInput.text === ""
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 10
                    color: cal6
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    onTextChanged: {
                        root.searchText = text
                        root.selectedIndex = 0
                    }
                    Keys.onEscapePressed: root.active = false
                    Keys.onReturnPressed: root.runSelected()
                    Keys.onTabPressed: root.fillFromSelection()
                    Keys.onUpPressed: {
                        if (root.filteredItems.length === 0) return
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                        itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    Keys.onDownPressed: {
                        if (root.filteredItems.length === 0) return
                        root.selectedIndex = Math.min(root.filteredItems.length - 1, root.selectedIndex + 1)
                        itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                }
            }

            ListView {
                id: itemList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredItems

                Text {
                    visible: root.filteredItems.length === 0
                    anchors.centerIn: parent
                    text: "No matches - Enter runs it as typed"
                    color: cal3
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize - 1
                }

                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 40
                    radius: 10
                    color: index === root.selectedIndex ? cal2 : "transparent"
                    border.width: 1
                    border.color: index === root.selectedIndex ? cal14 : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // Recency-clock glyph for a past command line,
                        // terminal glyph for a bare $PATH executable.
                        Text {
                            text: itemDelegate.modelData.isHistory ? "\uf017" : "\uf120"
                            color: itemDelegate.modelData.isHistory ? cal14 : cal3
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 2
                        }

                        Text {
                            text: itemDelegate.modelData.text
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
                        onEntered: root.selectedIndex = itemDelegate.index
                        onClicked: root.runCommand(itemDelegate.modelData.text)
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
