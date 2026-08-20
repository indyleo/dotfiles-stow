import QtQuick
import Quickshell.Io

// Battery controller reading directly from sysfs (like BrightnessController.qml).
// Finds the first available battery (BAT0, BAT1, ...) and exposes:
//   available, percentage, status, icon, text, show
Item {
    id: root

    property string batteryPath: ""          // e.g. "/sys/class/power_supply/BAT0"
    property int capacity: 0                 // 0–100
    property string status: ""               // "Charging", "Discharging", "Full", "Unknown"

    readonly property bool available: batteryPath !== ""
    readonly property int percentage: capacity
    readonly property bool show: available   // stays visible even at 0%, which is the most critical state

    readonly property string text: show ? percentage + "%" : ""

    readonly property string icon: {
        if (!show) return "󰂑"
        if (status === "Charging") {
            if (percentage >= 100) return "󰂅"
            if (percentage >= 90) return "󰂋"
            if (percentage >= 80) return "󰂊"
            if (percentage >= 70) return "󰢞"
            if (percentage >= 60) return "󰂉"
            if (percentage >= 50) return "󰢝"
            if (percentage >= 40) return "󰂈"
            if (percentage >= 30) return "󰂇"
            if (percentage >= 20) return "󰂆"
            if (percentage >= 10) return "󰢜"
            return "󰢟"
        } else if (status === "Discharging") {
            if (percentage >= 100) return "󰁹"
            if (percentage >= 90) return "󰂂"
            if (percentage >= 80) return "󰂁"
            if (percentage >= 70) return "󰂀"
            if (percentage >= 60) return "󰁿"
            if (percentage >= 50) return "󰁾"
            if (percentage >= 40) return "󰁽"
            if (percentage >= 30) return "󰁼"
            if (percentage >= 20) return "󰁻"
            if (percentage >= 10) return "󰁺"
            return "󰂎"
        } else if (status === "Full") {
            return "󰂄"
        }
        return "󰂑"
    }

    signal changed()
    onPercentageChanged: changed()
    onStatusChanged: changed()
    onAvailableChanged: changed()

    // Discover the first battery in /sys/class/power_supply/
    Process {
        id: discoverProc
        command: ["sh", "-c", "ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT[0-9]+$' | head -n1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim()
                if (name !== "") root.batteryPath = "/sys/class/power_supply/" + name
            }
        }
    }

    // Read capacity (0–100)
    FileView {
        id: capacityFile
        path: root.batteryPath !== "" ? root.batteryPath + "/capacity" : ""
        watchChanges: true
        onLoaded: root.capacity = parseInt(text(), 10) || 0
        onFileChanged: reload()
    }

    // Read status ("Charging", "Discharging", "Full", "Unknown")
    FileView {
        id: statusFile
        path: root.batteryPath !== "" ? root.batteryPath + "/status" : ""
        watchChanges: true
        onLoaded: root.status = text().trim()
        onFileChanged: reload()
    }

    // Fallback poll every 30 seconds (in addition to watchChanges above),
    // since some sysfs attributes don't reliably emit inotify events.
    // Only runs once a battery has actually been found.
    Timer {
        interval: 30000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: refresh()
    }

    function refresh() {
        if (root.batteryPath !== "") {
            // Force reload of sysfs files
            capacityFile.reload()
            statusFile.reload()
        }
    }
}