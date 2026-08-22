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

    property var items: []
    property string searchText: ""
    property int selectedIndex: 0
    property string promptText: "run"
    property string outputPath: ""

    // Colors/font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize
    readonly property color cal0: Theme.cal0
    readonly property color cal2: Theme.cal2
    readonly property color cal3: Theme.cal3
    readonly property color cal6: Theme.cal6
    readonly property color cal14: Theme.cal14

    screen: Quickshell.screens[0]
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors { top: true; bottom: true; left: true; right: true }

    // ------------------------------------------------------------
    // Invocation — called over IPC by the qsdmenu wrapper script:
    //   qs ipc call pick dmenu <inputFile> <outputFifo> <prompt>
    // ------------------------------------------------------------

    function open(inputFile, outFile, prompt) {
        root.outputPath = outFile
        root.promptText = prompt !== "" ? prompt : "run"
        root.selectedSet = {}
        inputFileView.path = inputFile
    }

    FileView {
        id: inputFileView
        onLoaded: {
            var content = text()
            root.items = content !== "" ? content.split("\n").filter(l => l !== "") : []
            root.searchText = ""
            root.selectedIndex = 0
            root.selectedSet = {}
            root.active = true
            focusTimer.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    // ------------------------------------------------------------
    // Multi-select — Ctrl+click toggles an item into this set without
    // submitting. Plain click keeps the original single-select behaviour
    // (submit immediately) so existing callers are unaffected. Enter
    // submits everything checked here, or falls back to the single-select
    // path if nothing's been Ctrl+clicked.
    // ------------------------------------------------------------

    property var selectedSet: ({})
    readonly property int selectedCount: Object.keys(root.selectedSet).length

    function toggleSelect(value) {
        var updated = Object.assign({}, root.selectedSet)
        if (updated[value]) delete updated[value]
        else updated[value] = true
        root.selectedSet = updated
    }

    // ------------------------------------------------------------
    // Result handoff — writes the selection into the fifo the
    // wrapper script is blocked reading, then closes the picker
    // ------------------------------------------------------------

    Process { id: writeProc }

    function submit(value) {
        if (root.outputPath !== "") {
            writeProc.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "write-result", value, root.outputPath]
            writeProc.running = false
            writeProc.running = true
        }
        root.active = false
        root.selectedSet = {}
    }

    function submitMulti(values) {
        if (root.outputPath !== "") {
            // $1 is the output path; shift it off so "$@" is exactly the
            // selected values (however many there are, however they're
            // spelled - passed via argv, never interpolated into the
            // script text, so no quoting concerns even with spaces/quotes
            // in an item).
            var script = 'out="$1"; shift; printf "%s\\n" "$@" > "$out"'
            writeProc.command = ["sh", "-c", script, "write-result-multi", root.outputPath].concat(values)
            writeProc.running = false
            writeProc.running = true
        }
        root.active = false
        root.selectedSet = {}
    }

    function submitSelected() {
        var list = root.filteredItems
        if (list.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < list.length) {
            root.submit(list[root.selectedIndex])
        } else {
            // No match highlighted — submit the raw typed text,
            // same as dmenu's "free text" behaviour.
            root.submit(root.searchText)
        }
    }

    // Enter key entry point: if anything's been Ctrl+click-selected,
    // submit that whole set; otherwise fall back to normal single-select.
    function confirm() {
        if (root.selectedCount > 0) {
            root.submitMulti(Object.keys(root.selectedSet))
        } else {
            root.submitSelected()
        }
    }

    function cancel() {
        root.submit("")
    }

    // ------------------------------------------------------------
    // Filtering
    // ------------------------------------------------------------

    readonly property var filteredItems: {
        var q = searchText.trim().toLowerCase()
        if (q === "") return items
        return items.filter(function(i) { return i.toLowerCase().includes(q) })
    }

    onFilteredItemsChanged: {
        if (root.selectedIndex >= filteredItems.length) root.selectedIndex = Math.max(0, filteredItems.length - 1)
    }

    // ------------------------------------------------------------
    // UI
    // ------------------------------------------------------------

    Rectangle {
        width: 480
        height: 480
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
                    text: root.promptText
                    color: cal6
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 4
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: root.selectedCount > 0
                    text: root.selectedCount + " selected"
                    color: cal14
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
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
                    onTextChanged: {
                        root.searchText = text
                        root.selectedIndex = 0
                    }
                    Keys.onEscapePressed: root.cancel()
                    Keys.onReturnPressed: root.confirm()
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

                delegate: Rectangle {
                    id: itemDelegate
                    required property string modelData
                    required property int index
                    readonly property bool isChecked: !!root.selectedSet[modelData]
                    width: ListView.view.width
                    height: 36
                    radius: 8
                    color: index === root.selectedIndex ? cal2 : "transparent"
                    border.width: 1
                    border.color: itemDelegate.isChecked ? cal14 : (index === root.selectedIndex ? cal14 : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            // Empty-box / checked-box glyph, only meaningful
                            // once at least one item has been Ctrl+clicked.
                            visible: root.selectedCount > 0
                            text: itemDelegate.isChecked ? "\uf14a" : "\uf0c8"
                            color: itemDelegate.isChecked ? cal14 : cal3
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: itemDelegate.modelData
                            color: cal6
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: root.selectedIndex = itemDelegate.index
                        onClicked: (mouse) => {
                            if (mouse.modifiers & Qt.ControlModifier) {
                                root.toggleSelect(itemDelegate.modelData)
                            } else {
                                root.submit(itemDelegate.modelData)
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
                    text: "Cancel"
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
                    onClicked: root.cancel()
                }
            }
        }
    }
}