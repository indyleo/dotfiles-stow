import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.Layouts
import QtCore

PanelWindow {
    id: root

    property bool active: false
    visible: active

    property var allApps: []
    property string searchText: ""
    property int selectedIndex: 0
    property var usage: ({})

    // Colors/font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize
    readonly property color cal0: Theme.cal0
    readonly property color cal2: Theme.cal2
    readonly property color cal3: Theme.cal3
    readonly property color cal6: Theme.cal6
    readonly property color cal14: Theme.cal14

    readonly property string cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell-launcher"
    readonly property string usageFile: cacheDir + "/usage.json"

    screen: Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { top: true; bottom: true; left: true; right: true }

    // ------------------------------------------------------------
    // App discovery
    // ------------------------------------------------------------

    // NUL-delimited discovery keeps desktop filenames intact, including spaces.
    readonly property string listScript: [
        "SEEN=$(mktemp)",
        "for d in \"$HOME/.local/share/applications\" \"/usr/local/share/applications\" \"/usr/share/applications\" \"/var/lib/flatpak/exports/share/applications\" \"$HOME/.local/share/flatpak/exports/share/applications\" \"/var/lib/snapd/desktop/applications\"; do",
        "  [ -d \"$d\" ] || continue",
        "  while IFS= read -r -d '' f; do",
        "    base=$(basename \"$f\")",
        "    nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-)",
        "    hidden=$(grep -m1 '^Hidden=' \"$f\" | cut -d= -f2-)",
        "    [ \"$nodisplay\" = \"true\" ] && continue",
        "    [ \"$hidden\" = \"true\" ] && continue",
        "    grep -qxF \"$base\" \"$SEEN\" 2>/dev/null && continue",
        "    echo \"$base\" >> \"$SEEN\"",
        "    name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)",
        "    [ -z \"$name\" ] && continue",
        "    icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-)",
        "    printf '%s\\x1f%s\\x1f%s\\0' \"$name\" \"$icon\" \"$f\"",
        "  done < <(find \"$d\" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)",
        "done",
        "rm -f \"$SEEN\""
    ].join("\n")

    Process {
        id: listProc
        command: ["bash", "-c", root.listScript]
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[AppLauncher] Failed to list applications:", code)
                return
            }
            // Records are NUL-delimited so whitespace in filenames is preserved.
            var records = listProc.stdout.text.split("\u0000").filter(r => r !== "")
            var apps = records.map(function(record) {
                var parts = record.split("\u001F")
                return { name: parts[0] || "", icon: parts[1] || "", path: parts.slice(2).join("\u001F") || "" }
            }).filter(a => a.name !== "" && a.path !== "")
            root.allApps = apps
        }
    }

    function refreshApps() {
        listProc.running = false
        listProc.running = true
    }

    // ------------------------------------------------------------
    // Usage / frecency
    // ------------------------------------------------------------
    // Previously this shelled out via `sh -c "cat '<path>' ..."` with the
    // path interpolated straight into a quoted shell string. If the cache
    // directory ever contained a single quote (an apostrophe in the
    // username, for instance) the command broke. FileView talks to the
    // filesystem directly and sidesteps shell quoting entirely.

    FileView {
        id: usageFileObj
        path: root.usageFile
    }

    // Directory creation is a real argv array, not a shell string, so no
    // quoting is needed here either.
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

    function loadUsage() {
        try {
            var parsed = JSON.parse(usageFileObj.text())
            root.usage = (parsed && typeof parsed === "object") ? parsed : {}
        } catch (e) {
            root.usage = {}
        }
    }

    function saveUsage() {
        var data = JSON.stringify(root.usage)
        mkdirProc.callback = function(code) {
            if (code === 0) {
                usageFileObj.setText(data)
            } else {
                console.warn("[AppLauncher] Failed to create cache dir:", code)
            }
        }
        mkdirProc.command = ["mkdir", "-p", root.cacheDir]
        mkdirProc.running = false
        mkdirProc.running = true
    }

    function bumpUsage(path) {
        var u = root.usage
        u[path] = (u[path] || 0) + 1
        root.usage = u
        saveUsage()
    }

    // ------------------------------------------------------------
    // Launching
    // ------------------------------------------------------------

    // dex isn't installed on every system. Detect once at startup and fall
    // back to gtk-launch or gio so app launches don't silently no-op.
    property string launchMethod: "dex"

    Process {
        id: detectLauncherProc
        command: ["sh", "-c",
            "command -v dex >/dev/null 2>&1 && echo dex || " +
            "{ command -v gtk-launch >/dev/null 2>&1 && echo gtk-launch || " +
            "{ command -v gio >/dev/null 2>&1 && echo gio || echo none; }; }"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.launchMethod = text.trim()
                if (root.launchMethod === "none") {
                    console.warn("[AppLauncher] No desktop-file launcher found (checked dex, gtk-launch, gio) - launching apps will not work")
                }
            }
        }
    }

    Process {
        id: launchProc
        property string launchPath: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[AppLauncher] Failed to launch:", code, launchProc.stderr.text)
            } else {
                console.log("[AppLauncher] Launched:", launchProc.launchPath)
            }
        }
    }

    function launchApp(app) {
        if (!app || !app.path) return

        var cmd
        if (root.launchMethod === "dex") {
            cmd = ["dex", app.path]
        } else if (root.launchMethod === "gtk-launch") {
            // gtk-launch wants a desktop-file *id* (basename, no extension,
            // no directory), resolved against XDG_DATA_DIRS.
            var base = app.path.split("/").pop().replace(/\.desktop$/, "")
            cmd = ["gtk-launch", base]
        } else if (root.launchMethod === "gio") {
            cmd = ["gio", "launch", app.path]
        } else {
            console.warn("[AppLauncher] Cannot launch, no launcher available:", app.path)
            return
        }

        // Use Quickshell's native detached execution to safely launch the app
        Quickshell.execDetached({ command: cmd })
        root.bumpUsage(app.path)
        root.active = false
    }

    function launchSelected() {
        var list = root.filteredApps
        if (list.length === 0) return
        var idx = Math.max(0, Math.min(root.selectedIndex, list.length - 1))
        root.launchApp(list[idx])
    }

    // ------------------------------------------------------------
    // Filtering / sorting (name match first, then frecency)
    // ------------------------------------------------------------

    readonly property var filteredApps: {
        var q = searchText.trim().toLowerCase()
        var list = allApps

        if (q !== "") {
            list = list.filter(function(a) { return a.name.toLowerCase().includes(q) })
        }

        list = list.slice().sort(function(a, b) {
            if (q !== "") {
                var aStarts = a.name.toLowerCase().startsWith(q) ? 0 : 1
                var bStarts = b.name.toLowerCase().startsWith(q) ? 0 : 1
                if (aStarts !== bStarts) return aStarts - bStarts
            }
            var au = root.usage[a.path] || 0
            var bu = root.usage[b.path] || 0
            if (au !== bu) return bu - au
            return a.name.localeCompare(b.name)
        })

        return list
    }

    onFilteredAppsChanged: {
        if (root.selectedIndex >= filteredApps.length) root.selectedIndex = Math.max(0, filteredApps.length - 1)
    }

    onActiveChanged: {
        if (active) {
            searchText = ""
            selectedIndex = 0
            refreshApps()
            loadUsage()
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

    Component.onCompleted: {
        detectLauncherProc.running = true
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
                text: "Launch"
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
                    text: "Search applications..."
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
                    Keys.onReturnPressed: root.launchSelected()
                    Keys.onUpPressed: {
                        if (root.filteredApps.length === 0) return
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                    Keys.onDownPressed: {
                        if (root.filteredApps.length === 0) return
                        root.selectedIndex = Math.min(root.filteredApps.length - 1, root.selectedIndex + 1)
                        appList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                    }
                }
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredApps

                Text {
                    visible: root.filteredApps.length === 0
                    anchors.centerIn: parent
                    text: "No applications found"
                    color: cal3
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize - 1
                }

                delegate: Rectangle {
                    id: appDelegate
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 44
                    radius: 10
                    color: index === root.selectedIndex ? cal2 : "transparent"
                    border.width: 1
                    border.color: index === root.selectedIndex ? cal14 : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        IconImage {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            source: Quickshell.iconPath(appDelegate.modelData.icon, "application-x-executable")
                        }

                        Text {
                            text: appDelegate.modelData.name
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
                        onEntered: root.selectedIndex = appDelegate.index
                        onClicked: root.launchApp(appDelegate.modelData)
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