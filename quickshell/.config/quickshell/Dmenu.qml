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

    // ------------------------------------------------------------
    // Invocation — called over IPC by the qsdmenu wrapper script:
    //   qs ipc call pick dmenu <inputFile> <outputFifo> <prompt>
    // ------------------------------------------------------------

    function open(inputFile, outFile, prompt) {
        root.outputPath = outFile
        root.promptText = prompt !== "" ? prompt : "run"
        inputFileView.path = inputFile
    }

    FileView {
        id: inputFileView
        onLoaded: {
            var content = text()
            root.items = content !== "" ? content.split("\n").filter(l => l !== "") : []
            root.searchText = ""
            root.selectedIndex = 0
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

            Text {
                text: root.promptText
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
                    Keys.onReturnPressed: root.submitSelected()
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
                    width: ListView.view.width
                    height: 36
                    radius: 8
                    color: index === root.selectedIndex ? cal2 : "transparent"
                    border.width: 1
                    border.color: index === root.selectedIndex ? cal14 : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: itemDelegate.modelData
                        color: cal6
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: root.selectedIndex = itemDelegate.index
                        onClicked: root.submit(itemDelegate.modelData)
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
