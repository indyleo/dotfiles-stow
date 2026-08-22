import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Layouts

// Small month calendar, opened by clicking the clock in the bar.
// Follows the same shape as WeatherController.qml: an Item wrapping a
// full-screen transparent PanelWindow with a centered content Rectangle,
// so it inherits the shell's existing popup conventions.
Item {
    id: root

    property bool active: false

    // Font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize

    // Month currently being displayed - defaults to the real current month
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth() // 0-11

    readonly property var weekdayLabels: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    function goPrevMonth() {
        if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear -= 1 }
        else root.viewMonth -= 1
    }
    function goNextMonth() {
        if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear += 1 }
        else root.viewMonth += 1
    }
    function goToday() {
        var d = new Date()
        root.viewYear = d.getFullYear()
        root.viewMonth = d.getMonth()
    }

    // Builds a flat 42-cell (6 week) grid for the given month, including
    // the trailing/leading days from the adjacent months so the grid is
    // always full and weekday columns line up.
    function buildCells(year, month) {
        var cells = []
        var firstOfMonth = new Date(year, month, 1)
        var startDow = firstOfMonth.getDay() // 0 = Sunday
        var daysInMonth = new Date(year, month + 1, 0).getDate()
        var daysInPrevMonth = new Date(year, month, 0).getDate()
        var today = new Date()

        for (var i = 0; i < startDow; i++) {
            cells.push({ day: daysInPrevMonth - startDow + 1 + i, inMonth: false, isToday: false })
        }
        for (var d = 1; d <= daysInMonth; d++) {
            var isToday = year === today.getFullYear() && month === today.getMonth() && d === today.getDate()
            cells.push({ day: d, inMonth: true, isToday: isToday })
        }
        var remaining = 42 - cells.length
        for (var t = 1; t <= remaining; t++) {
            cells.push({ day: t, inMonth: false, isToday: false })
        }
        return cells
    }

    property var cells: buildCells(root.viewYear, root.viewMonth)

    // Re-sync to the real current month/day whenever the popup is opened,
    // rather than staying wherever it was last navigated to.
    onActiveChanged: if (active) root.goToday()

    PanelWindow {
        id: calendarWindow
        screen: Quickshell.screens[0]
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; bottom: true; left: true; right: true }

        // Click anywhere outside the card to dismiss, same as pressing Escape.
        MouseArea {
            anchors.fill: parent
            onClicked: root.active = false
        }

        Rectangle {
            id: card
            width: 280
            height: 320
            anchors.centerIn: parent
            radius: 16
            color: Theme.background
            border.width: 2
            border.color: Theme.border

            // Swallow clicks so they don't fall through to the dismiss MouseArea above.
            MouseArea { anchors.fill: parent; onClicked: {} }

            Keys.onEscapePressed: root.active = false
            focus: root.active

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // Header: month/year + prev/next navigation
                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                        color: prevHover.hovered ? Theme.buttonHoverBg : Theme.buttonBg
                        Text { anchors.centerIn: parent; text: "\uf104"; color: Theme.text; font.family: root.fontFamily; font.pixelSize: root.fontSize }
                        MouseArea {
                            id: prevHover
                            property bool hovered: false
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: hovered = true; onExited: hovered = false
                            onClicked: root.goPrevMonth()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                        color: Theme.text
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize + 2
                        font.bold: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                        color: nextHover.hovered ? Theme.buttonHoverBg : Theme.buttonBg
                        Text { anchors.centerIn: parent; text: "\uf105"; color: Theme.text; font.family: root.fontFamily; font.pixelSize: root.fontSize }
                        MouseArea {
                            id: nextHover
                            property bool hovered: false
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: hovered = true; onExited: hovered = false
                            onClicked: root.goNextMonth()
                        }
                    }
                }

                // Weekday header row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: root.weekdayLabels
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.textMuted
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 2
                            font.bold: true
                        }
                    }
                }

                // Day grid - 7 columns x 6 rows
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 2

                    Repeater {
                        model: root.cells
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: modelData.isToday ? Theme.accent : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize - 1
                                font.bold: modelData.isToday
                                color: modelData.isToday ? Theme.background
                                    : (modelData.inMonth ? Theme.text : Theme.textMuted)
                                opacity: modelData.inMonth ? 1 : 0.5
                            }
                        }
                    }
                }

                // Footer: jump back to the real current month
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 26
                    radius: 13
                    color: todayHover.hovered ? Theme.buttonHoverBg : Theme.buttonBg
                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        color: Theme.text
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 1
                    }
                    MouseArea {
                        id: todayHover
                        property bool hovered: false
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: hovered = true; onExited: hovered = false
                        onClicked: root.goToday()
                    }
                }
            }
        }
    }
}
