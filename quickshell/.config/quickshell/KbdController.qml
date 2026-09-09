// KbdController.qml
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: controller

    property bool available: false
    property int level: 0
    property string icon: ""
    property string text: ""
    property bool pendingAdjust: false

    signal adjusted(int newLevel)

    Process {
        id: adjustProc
        property string action: ""
        stdout: StdioCollector {
            onStreamFinished: {
                controller.pendingAdjust = true
                refreshTimer.start()
            }
        }
    }

    Process {
        id: levelProc
        command: ["sysstats", "kbd_raw"]
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    const val = parseInt(data.trim())
                    if (!isNaN(val)) {
                        controller.level = val
                        controller.updateIconText()
                        if (controller.pendingAdjust) {
                            controller.pendingAdjust = false
                            controller.adjusted(controller.level)
                        }
                    }
                }
            }
        }
    }

    Process {
        id: checkProc
        command: ["sysstats", "kbd"]
        stdout: SplitParser {
            onRead: data => {
                if (data && !data.includes("N/A")) {
                    controller.available = true
                }
            }
        }
    }

    Component.onCompleted: {
        checkProc.running = true
        refreshLevel()
    }

    Timer {
        id: refreshTimer
        interval: 150
        onTriggered: refreshLevel()
    }

    function refreshLevel() {
        levelProc.running = false
        levelProc.running = true
    }

    function inc() {
        adjust("--inc")
    }

    function dec() {
        adjust("--dec")
    }

    function toggle() {
        adjust("--toggle")
    }

    function adjust(action) {
        if (!available) return
        adjustProc.command = ["sysctl", "kbd", action]
        adjustProc.running = false
        adjustProc.running = true
    }

    function updateIconText() {
        if (level === 0) {
            icon = "󰌌 󰃞"
        } else if (level <= 33) {
            icon = "󰌌 󰃝"
        } else if (level <= 66) {
            icon = "󰌌 󰃟"
        } else {
            icon = "󰌌 󰃠"
        }
        text = level + "%"
    }
}
