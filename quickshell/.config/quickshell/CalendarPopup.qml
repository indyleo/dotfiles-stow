import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

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

    // Builds a flat 42-cell (6 week) grid for the given month
    function buildCells(year, month) {
        var cells = []
        var firstOfMonth = new Date(year, month, 1)
        var startDow = firstOfMonth.getDay()
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

    onActiveChanged: if (active) { root.goToday(); root.syncFields() }

    // ---- Alarm ---------------------------------------------------------
    property string alarmMode: "at" // "at" | "in"

    property string atHH: "07"
    property string atMM: "00"
    property string atPeriod: "AM"

    property string inHH: "00"
    property string inMM: "01"
    property string inSS: "00"

    property bool alarmRepeat: false
    property bool alarmSet: false
    property double alarmTargetEpoch: 0
    property double alarmDurationMs: 0
    property int tick: 0

		// Alarm sound
property string alarmSoundScript: `
import math, struct, tempfile, subprocess, os

sr = 44100
duration = 1.1  # total length of the combined beeps

# (offset_seconds, frequency_hz) — first beep is 660, then 880, alternating
beeps = [
    (0.0, 660),
    (0.22, 880),
    (0.44, 660),
    (0.66, 880),
    (0.88, 660),
]

# Web Audio envelope constants (from the website's code)
attack_time = 0.015
decay_time = 0.165  # 0.18 - 0.015
start_amp = 0.0001
peak_amp = 0.18
end_amp = 0.0001

samples = []
for i in range(int(sr * duration)):
    t = i / sr
    val = 0.0
    for offset, freq in beeps:
        local_t = t - offset
        if 0 <= local_t < attack_time + decay_time:
            # Envelope
            if local_t < attack_time:
                # Exponential attack from start_amp to peak_amp
                gain = start_amp * (peak_amp / start_amp) ** (local_t / attack_time)
            else:
                # Exponential decay from peak_amp to end_amp
                k = (local_t - attack_time) / decay_time
                gain = peak_amp * (end_amp / peak_amp) ** k
            val += gain * math.sin(2 * math.pi * freq * local_t)
    # Soft clip to avoid harsh distortion
    val = max(-1.0, min(1.0, val))
    samples.append(struct.pack('<h', int(val * 32767)))

wav = b'RIFF' + struct.pack('<I', 36 + len(samples)*2) + b'WAVEfmt ' + struct.pack('<IHHIIHH', 16, 1, 1, sr, sr*2, 2, 16) + b'data' + struct.pack('<I', len(samples)*2) + b''.join(samples)

fd, path = tempfile.mkstemp(suffix='.wav')
with os.fdopen(fd, 'wb') as f:
    f.write(wav)

players = [
    ['paplay', path],
    ['aplay', path],
    ['play', path],
]
for cmd in players:
    try:
        subprocess.run(cmd, check=True)
        break
    except FileNotFoundError:
        continue
    except subprocess.CalledProcessError:
        break
os.unlink(path)
`

    function pad2(n) { return String(n).padStart(2, "0") }

    function syncFields() {
        hhField.value = root.alarmMode === "at" ? root.atHH : root.inHH
        mmField.value = root.alarmMode === "at" ? root.atMM : root.inMM
        if (ssField) ssField.value = root.inSS
    }
    function commitHH(v) { if (root.alarmMode === "at") root.atHH = v; else root.inHH = v }
    function commitMM(v) { if (root.alarmMode === "at") root.atMM = v; else root.inMM = v }
    function commitSS(v) { if (root.alarmMode === "in") root.inSS = v }

    function formatDuration(ms) {
        if (ms < 0) ms = 0
        var totalSec = Math.floor(ms / 1000)
        var hh = Math.floor(totalSec / 3600)
        var mm = Math.floor((totalSec % 3600) / 60)
        var ss = totalSec % 60
        return pad2(hh) + ":" + pad2(mm) + ":" + pad2(ss)
    }

    function setAlarm() {
        var h, m, s, maxH
        if (root.alarmMode === "at") {
            var h12 = parseInt(hhField.value, 10)
            m = parseInt(mmField.value, 10)
            var period = root.atPeriod
            if (isNaN(h12) || h12 < 1 || h12 > 12 || isNaN(m) || m < 0 || m > 59)
                return false

            h = h12
            if (period === "AM" && h12 === 12) h = 0
            else if (period === "PM" && h12 !== 12) h += 12

            var now = new Date()
            var target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, m, 0, 0)
            if (target.getTime() <= now.getTime())
                target.setDate(target.getDate() + 1)

            root.atHH = pad2(h12)
            root.atMM = pad2(m)
            root.atPeriod = period
            root.alarmTargetEpoch = target.getTime()
        } else {
            h = parseInt(hhField.value, 10)
            m = parseInt(mmField.value, 10)
            s = parseInt(ssField.value, 10)
            if (isNaN(h) || isNaN(m) || isNaN(s) || h < 0 || h > 99 || m < 0 || m > 59 || s < 0 || s > 59)
                return false

            var durationMs = ((h * 3600) + (m * 60) + s) * 1000
            if (durationMs <= 0) return false
            root.alarmDurationMs = durationMs
            root.alarmTargetEpoch = Date.now() + durationMs
            root.inHH = pad2(h); root.inMM = pad2(m); root.inSS = pad2(s)
        }

        root.syncFields()
        root.alarmSet = true
        alarmTimer.restartToTarget()
        return true
    }

    function cancelAlarm() {
        root.alarmSet = false
        alarmTimer.stop()
    }

    function fireAlarm() {
        var label
        if (root.alarmMode === "at") {
            label = "It's " + root.atHH + ":" + root.atMM + " " + root.atPeriod + "."
        } else {
            label = "Your " + root.inHH + ":" + root.inMM + ":" + root.inSS + " timer is up."
        }

        // Show notification
        alarmNotifyProc.command = ["notify-send", "-u", "critical", "-a", "Alarm", "Alarm", label]
        alarmNotifyProc.running = false
        alarmNotifyProc.running = true

        // Play beep sound
        playAlarmSound()

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

    function playAlarmSound() {
        alarmSoundProc.command = ["python3", "-c", root.alarmSoundScript]
        alarmSoundProc.running = false
        alarmSoundProc.running = true
    }

    Process { id: alarmNotifyProc }
    Process {
        id: alarmSoundProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[CalendarPopup] Failed to play alarm sound:", code, alarmSoundProc.stderr.text)
            }
        }
    }

    // Ticks once a second while an alarm is armed
    Timer {
        interval: 1000
        repeat: true
        running: root.alarmSet
        onTriggered: root.tick++
    }

    // Small 2-digit time field component
    component AlarmField: Rectangle {
        id: fieldRoot
        property alias value: fieldInput.text
        property int maxValue: 99
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
            validator: IntValidator { bottom: 0; top: fieldRoot.maxValue }
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: {
            if (visible) card.forceActiveFocus()
        }

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
            focus: true

            MouseArea { anchors.fill: parent; onClicked: {} }

            Keys.onEscapePressed: root.active = false

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

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                // Alarm section
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

                        // Once / repeat toggle
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

                    // Time entry
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        AlarmField {
                            id: hhField
                            value: root.atHH
                            maxValue: root.alarmMode === "at" ? 12 : 99
                            onCommitted: root.commitHH(value)
                            onSubmitRequested: root.setAlarm()
                            onCloseRequested: root.active = false
                        }
                        Text { text: ":"; color: Theme.textMuted; font.family: root.fontFamily; font.pixelSize: root.fontSize; font.bold: true }
                        AlarmField {
                            id: mmField
                            value: root.atMM
                            maxValue: 59
                            onCommitted: root.commitMM(value)
                            onSubmitRequested: root.setAlarm()
                            onCloseRequested: root.active = false
                        }

                        Text {
                            text: ":"
                            color: Theme.textMuted
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            font.bold: true
                            visible: root.alarmMode === "in"
                        }
                        AlarmField {
                            id: ssField
                            value: root.inSS
                            maxValue: 59
                            visible: root.alarmMode === "in"
                            onCommitted: root.commitSS(value)
                            onSubmitRequested: root.setAlarm()
                            onCloseRequested: root.active = false
                        }

                        // AM/PM toggle (only in "at" mode)
                        Rectangle {
                            id: ampmToggle
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 22
                            radius: 11
                            color: Theme.buttonBg
                            visible: root.alarmMode === "at"

                            Rectangle {
                                width: parent.width / 2
                                height: parent.height
                                radius: 11
                                x: root.atPeriod === "PM" ? parent.width / 2 : 0
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
                                    text: "AM"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 3
                                    color: root.atPeriod === "AM" ? Theme.background : Theme.text
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.atPeriod = "AM" }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "PM"
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSize - 3
                                    color: root.atPeriod === "PM" ? Theme.background : Theme.text
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.atPeriod = "PM" }
                                }
                            }
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

                    // Status line
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            var _ = root.tick
                            if (!root.alarmSet) return "No alarm set"
                            if (root.alarmMode === "in") {
                                var remain = root.alarmTargetEpoch - Date.now()
                                return "Alarm in " + root.formatDuration(remain) + (root.alarmRepeat ? " (repeating)" : "")
                            }
                            return "Alarm set for " + root.atHH + ":" + root.atMM + " " + root.atPeriod
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
