import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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
    onActiveChanged: if (active) { root.goToday(); root.syncFields() }

    // ---- Alarm ---------------------------------------------------------
    // A single alarm, in one of two modes:
    //   "at" - fires at a specific time of day (HH:MM:SS), optionally daily
    //   "in" - fires after a duration from now (HH:MM:SS from now),
    //          optionally repeating every that duration
    // Each mode keeps its own field values so switching modes doesn't
    // clobber what you typed into the other one. Lives on this Item
    // (instantiated once by shell.qml and kept alive, only visibility
    // toggles) so the countdown Timer keeps running while the popup is
    // closed.
    property string alarmMode: "at" // "at" | "in"

    property string atHH: "07"
    property string atMM: "00"
    property string atSS: "00"

    property string inHH: "00"
    property string inMM: "01"
    property string inSS: "00"

    property bool alarmRepeat: false
    property bool alarmSet: false
    property double alarmTargetEpoch: 0 // ms timestamp of the next trigger
    property double alarmDurationMs: 0  // "in" mode only - the duration to re-apply on repeat
    property int tick: 0                // bumped every second while armed, just to force the status/countdown text to re-evaluate

    function pad2(n) { return String(n).padStart(2, "0") }

    // Pushes the backing values for the current mode into the on-screen
    // HH/MM/SS fields. Called on mode switch and whenever the popup opens,
    // since the fields aren't kept permanently bound (see AlarmField note).
    function syncFields() {
        hhField.value = root.alarmMode === "at" ? root.atHH : root.inHH
        mmField.value = root.alarmMode === "at" ? root.atMM : root.inMM
        ssField.value = root.alarmMode === "at" ? root.atSS : root.inSS
    }
    function commitHH(v) { if (root.alarmMode === "at") root.atHH = v; else root.inHH = v }
    function commitMM(v) { if (root.alarmMode === "at") root.atMM = v; else root.inMM = v }
    function commitSS(v) { if (root.alarmMode === "at") root.atSS = v; else root.inSS = v }

    function formatDuration(ms) {
        if (ms < 0) ms = 0
        var totalSec = Math.floor(ms / 1000)
        var hh = Math.floor(totalSec / 3600)
        var mm = Math.floor((totalSec % 3600) / 60)
        var ss = totalSec % 60
        return pad2(hh) + ":" + pad2(mm) + ":" + pad2(ss)
    }

    // Validates the current mode's fields and (re)arms the timer.
    //   "at": next occurrence of that time (today if it hasn't passed, else tomorrow)
    //   "in": now + that duration
    // Returns false without changing anything if the fields don't parse.
    function setAlarm() {
        var h, m, s, maxH
        if (root.alarmMode === "at") {
            h = parseInt(root.atHH, 10); m = parseInt(root.atMM, 10); s = parseInt(root.atSS, 10)
            maxH = 23
        } else {
            h = parseInt(root.inHH, 10); m = parseInt(root.inMM, 10); s = parseInt(root.inSS, 10)
            maxH = 99
        }
        if (isNaN(h) || isNaN(m) || isNaN(s) || h < 0 || h > maxH || m < 0 || m > 59 || s < 0 || s > 59)
            return false

        var target
        if (root.alarmMode === "at") {
            var now = new Date()
            target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, m, s, 0)
            if (target.getTime() <= now.getTime())
                target.setDate(target.getDate() + 1)
            root.atHH = pad2(h); root.atMM = pad2(m); root.atSS = pad2(s)
        } else {
            var durationMs = ((h * 3600) + (m * 60) + s) * 1000
            if (durationMs <= 0) return false
            root.alarmDurationMs = durationMs
            target = new Date(Date.now() + durationMs)
            root.inHH = pad2(h); root.inMM = pad2(m); root.inSS = pad2(s)
        }

        root.syncFields()
        root.alarmTargetEpoch = target.getTime()
        root.alarmSet = true
        alarmTimer.restartToTarget()
        return true
    }

    function cancelAlarm() {
        root.alarmSet = false
        alarmTimer.stop()
    }

    function fireAlarm() {
        var label = root.alarmMode === "at"
            ? "It's " + root.atHH + ":" + root.atMM + ":" + root.atSS + "."
            : "Your " + root.inHH + ":" + root.inMM + ":" + root.inSS + " timer is up."
        alarmNotifyProc.command = ["notify-send", "-u", "critical", "-a", "Alarm", "Alarm", label]
        alarmNotifyProc.running = false
        alarmNotifyProc.running = true

        if (root.alarmRepeat) {
            var next
            if (root.alarmMode === "at") {
                next = new Date(root.alarmTargetEpoch)
                next.setDate(next.getDate() + 1)
            } else {
                next = new Date(Date.now() + root.alarmDurationMs)
            }
            root.alarmTargetEpoch = next.getTime()
            alarmTimer.restartToTarget()
        } else {
            root.alarmSet = false
        }
    }

    Process { id: alarmNotifyProc }

    // Ticks once a second while an alarm is armed, purely to force the
    // status/countdown Text below to re-evaluate (it reads Date.now()).
    Timer {
        interval: 1000
        repeat: true
        running: root.alarmSet
        onTriggered: root.tick++
    }

    // Small 2-digit time field used for the HH / MM / SS inputs below.
    // Inline components can't reference ids from the surrounding document
    // (only the Theme singleton, which isn't id-scoped), so this talks back
    // to root purely through property bindings + signals set up at the
    // call site, the same way the rest of the shell's components do.
    component AlarmField: Rectangle {
        id: fieldRoot
        property alias value: fieldInput.text
        signal committed()
        signal submitRequested()
        signal closeRequested()
        Layout.preferredWidth: 34
        Layout.preferredHeight: 28
        radius: 8
        color: Theme.surfaceAlt
        border.width: 1
        border.color: fieldInput.activeFocus ? Theme.accent : Theme.border

        TextInput {
            id: fieldInput
            anchors.fill: parent
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            maximumLength: 2
            validator: IntValidator { bottom: 0; top: 99 }
            selectByMouse: true
            onEditingFinished: {
                if (text !== "") text = text.padStart(2, "0")
                fieldRoot.committed()
            }
            Keys.onReturnPressed: fieldRoot.submitRequested()
            Keys.onEnterPressed: fieldRoot.submitRequested()
            Keys.onEscapePressed: fieldRoot.closeRequested()
        }
    }

    Timer {
        id: alarmTimer
        repeat: false
        onTriggered: root.fireAlarm()
        // QML Timer.interval is a 32-bit ms value (~24.8 day ceiling), which
        // a daily/once alarm never approaches, but this keeps the call safe
        // regardless.
        function restartToTarget() {
            stop()
            var ms = root.alarmTargetEpoch - Date.now()
            interval = Math.max(0, Math.min(ms, 2147000000))
            start()
        }
    }

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
            height: 430
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

                // Divider between the calendar grid and the alarm section
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                // Alarm: at a set time, or in a duration from now
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: "Alarm"
                            color: Theme.text
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 1
                            font.bold: true
                        }

                        // At / In mode toggle
                        Rectangle {
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 22
                            radius: 11
                            color: Theme.buttonBg

                            Rectangle {
                                width: parent.width / 2
                                height: parent.height
                                radius: 11
                                x: root.alarmMode === "in" ? parent.width / 2 : 0
                                color: Theme.blue
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "At"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 3
                                    color: root.alarmMode === "in" ? Theme.text : Theme.background
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.alarmMode = "at"; root.syncFields() } }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "In"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 3
                                    color: root.alarmMode === "in" ? Theme.background : Theme.text
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.alarmMode = "in"; root.syncFields() } }
                                }
                            }
                        }

                        // Once / repeat toggle - label adapts to mode ("Daily" for
                        // a clock time, "Repeat" for a duration that re-fires
                        // every time it elapses)
                        Rectangle {
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 22
                            radius: 11
                            color: Theme.buttonBg

                            Rectangle {
                                width: parent.width / 2
                                height: parent.height
                                radius: 11
                                x: root.alarmRepeat ? parent.width / 2 : 0
                                color: Theme.accent
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Once"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 3
                                    color: root.alarmRepeat ? Theme.text : Theme.background
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.alarmRepeat = false }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: root.alarmMode === "at" ? "Daily" : "Repeat"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 3
                                    color: root.alarmRepeat ? Theme.background : Theme.text
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.alarmRepeat = true }
                                }
                            }
                        }
                    }

                    // HH : MM : SS entry - a clock time in "at" mode, a
                    // duration from now in "in" mode
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        AlarmField {
                            id: hhField; value: root.atHH
                            onCommitted: root.commitHH(value)
                            onSubmitRequested: root.setAlarm()
                            onCloseRequested: root.active = false
                        }
                        Text { text: ":"; color: Theme.textMuted; font.family: root.fontFamily; font.pixelSize: root.fontSize; font.bold: true }
                        AlarmField {
                            id: mmField; value: root.atMM
                            onCommitted: root.commitMM(value)
                            onSubmitRequested: root.setAlarm()
                            onCloseRequested: root.active = false
                        }
                        Text { text: ":"; color: Theme.textMuted; font.family: root.fontFamily; font.pixelSize: root.fontSize; font.bold: true }
                        AlarmField {
                            id: ssField; value: root.atSS
                            onCommitted: root.commitSS(value)
                            onSubmitRequested: root.setAlarm()
                            onCloseRequested: root.active = false
                        }

                        Item { Layout.fillWidth: true }

                        // Set / Cancel button
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 28
                            radius: 8
                            color: setAlarmHover.hovered ? Theme.buttonHoverBg : Theme.buttonBg
                            Text {
                                anchors.centerIn: parent
                                text: root.alarmSet ? "Cancel" : "Set"
                                color: root.alarmSet ? Theme.danger : Theme.text
                                font.family: root.fontFamily
                                font.pixelSize: root.fontSize - 2
                            }
                            MouseArea {
                                id: setAlarmHover
                                property bool hovered: false
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: hovered = true; onExited: hovered = false
                                onClicked: root.alarmSet ? root.cancelAlarm() : root.setAlarm()
                            }
                        }
                    }

                    // Status line: confirms what's armed (with a live
                    // countdown in "in" mode), or flags nothing's set
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            var _ = root.tick // force re-eval every second while armed
                            if (!root.alarmSet) return "No alarm set"
                            if (root.alarmMode === "in") {
                                var remain = root.alarmTargetEpoch - Date.now()
                                return "Alarm in " + root.formatDuration(remain) + (root.alarmRepeat ? " (repeating)" : "")
                            }
                            return "Alarm set for " + root.atHH + ":" + root.atMM + ":" + root.atSS
                                + (root.alarmRepeat ? " (daily)" : " (once, "
                                + Qt.formatDate(new Date(root.alarmTargetEpoch), "MMM d") + ")")
                        }
                        color: root.alarmSet ? Theme.accent : Theme.textMuted
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 3
                    }
                }
            }
        }
    }
}
