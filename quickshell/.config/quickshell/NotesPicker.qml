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

		property string notesDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/Documents/Markdown/Notes"

    property var notesList: []
    property string searchText: ""
    property string newNoteName: ""

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
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { top: true; bottom: true; left: true; right: true }

    // List notes
    Process {
        id: listProc
        command: [
            "sh", "-c",
            "find '" + root.notesDir + "' -maxdepth 2 -type f ! -path '*/.*' -printf '%T@ ./%P\\n' 2>/dev/null | sort -nr | cut -d' ' -f2-"
        ]
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code === 0) {
                var lines = listProc.stdout.text.trim().split("\n").filter(s => s !== "");
                root.notesList = lines;
                console.warn("[NotesPicker] Loaded", lines.length, "notes");
            } else {
                console.warn("[NotesPicker] find failed:", code);
            }
        }
    }

    // Create notes directory if missing, then list
    Process {
        id: mkdirProc
        onExited: (code, status) => {
            if (code === 0) {
                listProc.running = false;
                listProc.running = true;
            }
        }
    }

    function refreshNotes() {
        mkdirProc.command = ["sh", "-c", "mkdir -p '" + root.notesDir + "'"];
        mkdirProc.running = false;
        mkdirProc.running = true;
    }

    // Open a note with footclient
    Process { id: openProc }

    function openNote(filePath) {
        openProc.command = ["footclient", "-e", "nvim", filePath];
        openProc.running = false;
        openProc.running = true;
        root.active = false;
    }

    // Create a new note (gennotes logic)
    Process {
        id: createProc
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code === 0) {
                var filePath = createProc.stdout.text.trim();
                if (filePath !== "") openNote(filePath);
            } else {
                console.warn("[NotesPicker] create failed:", code);
            }
        }
    }

    function createNewNote(name) {
        var timestamp = new Date().toISOString().replace(/[:.]/g, "-");
        var noteBase = name !== "" ? name : timestamp;
        var today = new Date().toISOString().split("T")[0];

        var script = [
            "notes_dir='" + root.notesDir + "'",
            "day_dir=\"${notes_dir}/" + today + "\"",
            "notes_name=\"Notes_${1:-" + timestamp + "}\"",
            "notes_file=\"${day_dir}/${notes_name}.md\"",
            "mkdir -p \"$notes_dir\" \"$day_dir\"",
            "if [[ ! -f \"$notes_file\" ]]; then",
            "    echo \"#  Notes - " + today + "\" > \"$notes_file\"",
            "fi",
            "printf '%s' \"$notes_file\""
        ].join("\n");

        createProc.command = ["bash", "-c", script, "gennotes", noteBase];
        createProc.running = false;
        createProc.running = true;
    }

    onActiveChanged: {
        if (active) {
            newNoteName = "";
            searchText = "";
            refreshNotes();
            focusTimer.start();
        }
    }

    Timer {
        id: focusTimer
        interval: 100
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    // Filtered notes
    readonly property var filteredNotes: {
        if (searchText === "") return notesList;
        return notesList.filter(function(n) {
            return n.toLowerCase().includes(searchText.toLowerCase());
        });
    }

    Rectangle {
        width: 500
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

            Text {
                text: "Notes"
                color: cal6
                font.family: root.fontFamily
                font.pixelSize: root.fontSize + 4
                font.bold: true
            }

            // Search input
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
                    text: "Search notes..."
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
                    onTextChanged: root.searchText = text
                    Keys.onEscapePressed: root.active = false
                }
            }

            // New note input row
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    id: newNoteInputRect
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
                        text: "New note name (optional)"
                        color: cal3
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        visible: newNoteInput.text === ""
                    }

                    TextInput {
                        id: newNoteInput
                        anchors.fill: parent
                        anchors.margins: 10
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.newNoteName = text
                        Keys.onEscapePressed: root.active = false
                        Keys.onReturnPressed: root.createNewNote(root.newNoteName)
                    }
                }

                Rectangle {
                    id: newBtn
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: 100
                    radius: 10
                    color: cal2
                    border.width: 2
                    border.color: cal3
                    Text {
                        anchors.centerIn: parent
                        text: "Create"
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: { newBtn.color = cal3; newBtn.border.color = cal6; }
                        onExited: { newBtn.color = cal2; newBtn.border.color = cal3; }
                        onClicked: root.createNewNote(root.newNoteName)
                    }
                }
            }

            // Notes list
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredNotes

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 40
                    radius: 10
                    color: cal2
                    border.width: 1
                    border.color: cal3
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.replace(/^\.\//, "")
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.border.color = cal14
                        onExited: parent.border.color = cal3
                        onClicked: root.openNote(root.notesDir + "/" + modelData.replace(/^\.\//, ""))
                    }
                }
            }

            // Close button
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
                    onEntered: { closeBtn.color = cal3; closeBtn.border.color = cal6; }
                    onExited: { closeBtn.color = cal2; closeBtn.border.color = cal3; }
                    onClicked: root.active = false
                }
            }
        }
    }
}
