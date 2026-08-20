import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts
import QtCore

Item {
    id: root

    property bool active: false
    property var history: []
    property var pinned: []

    // Maximum number of image entries (history + pinned) before old ones are removed.
    // Only unpinned history images are removed automatically.
    property int maxImages: 25

    property string fontFamily: "sans-serif"
    property int fontSize: 14

    readonly property string cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell-clipboard"
    readonly property string historyFile: cacheDir + "/history.json"
    readonly property string pinnedFile: cacheDir + "/pinned.json"
    readonly property string imageDir: cacheDir + "/images"

		// ------------------------------------------------------------
    // Synchronous file handling – prevents data loss on reload
    // ------------------------------------------------------------

    FileView {
        id: historyFileObj
        path: root.historyFile
    }

    FileView {
        id: pinnedFileObj
        path: root.pinnedFile
    }

    function loadHistory() {
        try {
            var parsed = JSON.parse(historyFileObj.text())
            history = Array.isArray(parsed) ? parsed : []
            console.log("[Clipboard] History loaded:", history.length)
        } catch (e) {
            console.warn("[Clipboard] Failed to parse history:", e)
            history = []
            saveHistory()
        }
    }

    function loadPinned() {
        try {
            var parsed = JSON.parse(pinnedFileObj.text())
            pinned = Array.isArray(parsed) ? parsed : []
        } catch (e) {
            console.warn("[Clipboard] Failed to parse pinned:", e)
            pinned = []
            savePinned()
        }
    }

    function saveHistory() {
        var data = JSON.stringify(history, null, 2)
        historyFileObj.setText(data)
        console.log("[Clipboard] History saved, entries:", history.length)
    }

    function savePinned() {
        var data = JSON.stringify(pinned, null, 2)
        pinnedFileObj.setText(data)
    }

    // ------------------------------------------------------------
    // Image limit enforcement
    // ------------------------------------------------------------

    function enforceImageLimit() {
        if (root.maxImages <= 0) return

        // Count all images (history + pinned)
        var imageCount = 0
        for (var i = 0; i < history.length; i++)
            if (history[i].type === "image") imageCount++
        for (var j = 0; j < pinned.length; j++)
            if (pinned[j].type === "image") imageCount++

        var excess = imageCount - root.maxImages
        if (excess <= 0) return

        // Remove oldest unpinned images from history (from the end)
        for (var k = history.length - 1; k >= 0 && excess > 0; k--) {
            if (history[k].type === "image") {
                var removed = history[k]
                history.splice(k, 1)
                deleteImageIfUnreferenced(removed.imagePath)
                excess--
            }
        }
        saveHistory()
    }

    // ------------------------------------------------------------
    // Clipboard monitoring
    // ------------------------------------------------------------

    Process {
        id: clipboardWatch

        command: [
            "wl-paste", "--watch", "sh", "-c",
            "TYPES=$(wl-paste --list-types 2>/dev/null)\n" +
            "if printf '%s\\n' \"$TYPES\" | grep -q 'image/png'; then\n" +
            "    mkdir -p \"$1\"\n" +
            "    FILE=\"$1/clip_$(date +%s%N).png\"\n" +
            "    if wl-paste --type image/png > \"$FILE\" 2>/dev/null; then\n" +
            "        printf 'IMAGE|%s\\n' \"$FILE\"\n" +
            "    else\n" +
            "        rm -f \"$FILE\"\n" +
            "    fi\n" +
            "else\n" +
            "    DATA=$(wl-paste --no-newline 2>/dev/null | base64 -w0)\n" +
            "    if [ -n \"$DATA\" ]; then\n" +
            "        printf 'TEXT64|%s\\n' \"$DATA\"\n" +
            "    fi\n" +
            "fi",
            "clipboard-watch",   // $0
            imageDir             // $1
        ]

        stdout: SplitParser {
            onRead: function(line) {
                var data = line.trim()
                console.log("[Clipboard] Watcher output:", data)

                if (data === "") return

                if (data.startsWith("TEXT64|")) {
                    var encoded = data.substring(7)
                    console.log("[Clipboard] Decoding base64, length:", encoded.length)

                    decodeProc.command = [
                        "sh", "-c",
                        "echo \"$1\" | base64 -d",
                        "decode",
                        encoded
                    ]
                    decodeProc.running = false
                    decodeProc.running = true

                } else if (data.startsWith("IMAGE|")) {
                    var imagePath = data.substring(6)
                    if (imagePath !== "")
                        root.addClip("image", "", imagePath)
                }
            }
        }

        onStarted: {
            console.log("[Clipboard] watcher started")
        }

        onExited: function(code, status) {
            console.warn("[Clipboard] watcher exited:", code, status)
            restartClipboardTimer.start()
        }
    }

    Process {
        id: decodeProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("[Clipboard] Decoded text:", text)
                    root.addClip("text", text, "")
                } else {
                    console.warn("[Clipboard] Decoded text is empty (process may have failed)")
                }
            }
        }

        onStarted: {
            console.log("[Clipboard] decodeProc started")
        }

        onExited: function(code, status) {
            console.log("[Clipboard] decodeProc exited with code", code, "status", status)
        }
    }

    Timer {
        id: restartClipboardTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!clipboardWatch.running)
                clipboardWatch.running = true
        }
    }

    // ------------------------------------------------------------
    // History management
    // ------------------------------------------------------------

    function addClip(type, content, imagePath) {
        console.log("[Clipboard] addClip called:", type, content ? content.substring(0,30) : "", imagePath)

        if (type === "text" && (!content || content.length === 0)) {
            console.log("[Clipboard] Ignoring empty text")
            return
        }

        // Avoid duplicates
        for (var i = 0; i < history.length; i++) {
            var h = history[i]
            if (h.type === type && (type === "text" ? h.content === content : h.imagePath === imagePath)) {
                console.log("[Clipboard] Duplicate, ignoring")
                return
            }
        }

        if (isPinned({type: type, content: content, imagePath: imagePath})) {
            console.log("[Clipboard] Already pinned, ignoring")
            return
        }

        // Create new entry and reassign history (so QML signals fire)
        var entry = {
            type: type,
            content: content,
            imagePath: imagePath,
            timestamp: Date.now()
        }

        history = [entry, ...history].slice(0, 150)

        // Enforce image limit (saves history as well)
        enforceImageLimit()
        console.log("[Clipboard] Added to history, total:", history.length)
    }

    function togglePin(clip) {
        var idx = -1
        for (var i = 0; i < pinned.length; i++) {
            if (pinned[i].type === clip.type &&
                (clip.type === "text" ? pinned[i].content === clip.content : pinned[i].imagePath === clip.imagePath)) {
                idx = i
                break
            }
        }

        if (idx >= 0) {
            // Remove from pinned and add back to history
            var removed = pinned[idx]
            pinned = pinned.filter((_, i) => i !== idx)
            history = [removed, ...history].slice(0, 150)
        } else {
            // Add to pinned and remove from history
            pinned = [clip, ...pinned]
            history = history.filter(h =>
                !(h.type === clip.type &&
                  (clip.type === "text" ? h.content === clip.content : h.imagePath === clip.imagePath))
            )
        }
        saveHistory()
        savePinned()
    }

    Process {
        id: deleteFileProc
        function run(cmd) { command = cmd; running = false; running = true }
    }

    // Deletes an image file from disk, but only if it's no longer
    // referenced by any remaining history/pinned entry.
    function deleteImageIfUnreferenced(imagePath) {
        if (!imagePath) return
        var stillReferenced = history.some(h => h.type === "image" && h.imagePath === imagePath) ||
                               pinned.some(p => p.type === "image" && p.imagePath === imagePath)
        if (!stillReferenced)
            deleteFileProc.run(["rm", "-f", imagePath])
    }

    function removeClip(clip) {
        if (isPinned(clip)) {
            pinned = pinned.filter(p =>
                !(p.type === clip.type &&
                  (clip.type === "text" ? p.content === clip.content : p.imagePath === clip.imagePath))
            )
        }
        history = history.filter(h =>
            !(h.type === clip.type &&
              (clip.type === "text" ? h.content === clip.content : h.imagePath === clip.imagePath))
        )
        saveHistory()
        savePinned()

        if (clip.type === "image")
            deleteImageIfUnreferenced(clip.imagePath)
    }

    function pasteClip(clip) {
        if (clip.type === "text") {
            copyProc.command = ["wl-copy", "--", clip.content]
        } else if (clip.type === "image") {
            copyProc.command = ["sh", "-c", "wl-copy --type image/png < \"$1\"", "clipboard-copy", clip.imagePath]
        }
        copyProc.running = false
        copyProc.running = true
    }

    function isPinned(clip) {
        for (var i = 0; i < pinned.length; i++) {
            if (pinned[i].type === clip.type &&
                (clip.type === "text" ? pinned[i].content === clip.content : pinned[i].imagePath === clip.imagePath))
                return true
        }
        return false
    }

    Process {
        id: copyProc
        onExited: function(code, status) {
            if (code !== 0)
                console.warn("[Clipboard] wl-copy failed:", code, status)
        }
    }

		// ------------------------------------------------------------
    // Overlay UI (uses fixed font and pixel size)
    // ------------------------------------------------------------

    PanelWindow {
        id: clipboardWindow
        screen: Quickshell.screens[0]
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        anchors { top: true; right: true; bottom: true }
        margins.top: 42; margins.right: 12; margins.bottom: 12
        implicitWidth: 340

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: "#282828"
            border.width: 2
            border.color: "#504945"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: clipHeaderText.implicitWidth + 20
                        radius: 13
                        color: "#3c3836"

                        Text {
                            id: clipHeaderText
                            anchors.centerIn: parent
                            text: "📋 Clipboard"
                            color: "#d5c4a1"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: clearText.implicitWidth + 20
                        radius: 13
                        color: "#3c3836"

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "Clear"
                            color: "#fb4934"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cleared = root.history
                                root.history = []
                                root.saveHistory()
                                for (var i = 0; i < cleared.length; i++) {
                                    if (cleared[i].type === "image")
                                        root.deleteImageIfUnreferenced(cleared[i].imagePath)
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#504945" }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: root.pinned.concat(root.history)

                    Text {
                        visible: root.pinned.length === 0 && root.history.length === 0
                        anchors.centerIn: parent
                        text: "No clipboard items"
                        color: "#bdae93"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: clipRow.implicitHeight + 12
                        radius: 13
                        color: "#3c3836"

                        RowLayout {
                            id: clipRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Item {
                                visible: modelData.type === "image"
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: "#282828"
                                }

                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    source: modelData.type === "image" && modelData.imagePath
                                            ? "file://" + modelData.imagePath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: thumb.status !== Image.Ready
                                    text: ""
                                    color: "#bdae93"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (modelData.type === "text")
                                            return modelData.content !== undefined ? modelData.content.substring(0, 60) : ""
                                        if (modelData.type === "image")
                                            return "Image: " + (modelData.imagePath !== undefined ? modelData.imagePath.split("/").pop() : "")
                                        return ""
                                    }
                                    color: "#ebdbb2"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.bold: false
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 3
                                }
                            }

                            // Pin Button
                            Text {
                                text: root.isPinned(modelData) ? "" : ""
                                color: root.isPinned(modelData) ? "#fabd2f" : "#7c6f64"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePin(modelData)
                                }
                            }

                            // Paste Button
                            Text {
                                text: ""
                                color: "#83a598"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pasteClip(modelData)
                                }
                            }

                            // Delete Button
                            Text {
                                text: "✕"
                                color: "#fb4934"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeClip(modelData)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pasteClip(modelData)
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // Startup
    // ------------------------------------------------------------

    Process {
        id: shellProc
        onExited: {
            // Directory should now exist, so loading and saving are safe
            loadHistory()
            loadPinned()
            enforceImageLimit()          // cleanup if previous run exceeded the limit
            clipboardWatch.running = true
        }
    }

    Component.onCompleted: {
        shellProc.command = ["mkdir", "-p", cacheDir, imageDir]
        shellProc.running = true
    }
}
