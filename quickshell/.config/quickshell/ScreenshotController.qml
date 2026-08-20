import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    // Keep the window hidden normally; it only appears for region selection
    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    screen: Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    signal backgroundCaptured(string filePath)
    signal screenshotCaptured(string filePath)
    signal colorPicked(string hexColor)
    signal screenshotFailed(string reason)

    // Public API
    function screenshotFull()    { captureFull() }
    function screenshotWindow()  { captureWindow() }
    function screenshotMonitor() { captureMonitor() }
    function screenshotRegion()  { showRegionSelector() }
    function colorPicker()       { pickColor() }

    // Timestamp helper
    function getTimestamp() {
        var now = new Date()
        var y = now.getFullYear()
        var mo = String(now.getMonth() + 1).padStart(2, "0")
        var d = String(now.getDate()).padStart(2, "0")
        var h = String(now.getHours()).padStart(2, "0")
        var mi = String(now.getMinutes()).padStart(2, "0")
        var s = String(now.getSeconds()).padStart(2, "0")
        return y + "-" + mo + "-" + d + "_" + h + "-" + mi + "-" + s
    }

    // Save, copy, notify after successful capture
    function finalizeImage(filePath) {
        root.screenshotCaptured(filePath)

        copyImageProc.command = ["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", filePath]
        copyImageProc.running = false
        copyImageProc.running = true

        var timestamp = getTimestamp()
        var filename = timestamp + ".png"
        var saveDir = "$HOME/Pictures/Screenshots"

        saveImageProc.command = [
            "sh", "-c",
            "mkdir -p \"" + saveDir + "\" && cp \"$1\" \"" + saveDir + "/$2\" && notify-send 'Screenshot Captured' \"Saved to: $2\" -i \"" + saveDir + "/$2\"",
            "sh",
            filePath,
            filename
        ]
        saveImageProc.running = false
        saveImageProc.running = true
    }

    // --- Region selection overlay ---
    property bool regionSelectorVisible: false

    function showRegionSelector() {
        regionSelectorVisible = true
        root.visible = true
        selectionRect.visible = false
        regionMouseArea.selecting = false
    }

    function hideRegionSelector() {
        regionSelectorVisible = false
        root.visible = false
        selectionRect.visible = false
    }

    // Full-screen semi-transparent overlay
    Rectangle {
        id: regionOverlay
        anchors.fill: parent
        visible: regionSelectorVisible
        color: Qt.rgba(0, 0, 0, 0.3)
        focus: true

        // Rectangle showing the selection
        Rectangle {
            id: selectionRect
            color: Qt.rgba(1, 1, 1, 0.2)
            border.color: "white"
            border.width: 2
            visible: false
        }

        MouseArea {
            id: regionMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.CrossCursor

            property real startX: 0
            property real startY: 0
            property bool selecting: false

            onPressed: (mouse) => {
                if (mouse.button !== Qt.LeftButton) return
                selecting = true
                startX = mouse.x
                startY = mouse.y
                selectionRect.x = startX
                selectionRect.y = startY
                selectionRect.width = 0
                selectionRect.height = 0
                selectionRect.visible = true
            }

            onPositionChanged: (mouse) => {
                if (!selecting) return
                var x = Math.min(startX, mouse.x)
                var y = Math.min(startY, mouse.y)
                var w = Math.abs(mouse.x - startX)
                var h = Math.abs(mouse.y - startY)

                selectionRect.x = x
                selectionRect.y = y
                selectionRect.width = w
                selectionRect.height = h
            }

            onReleased: (mouse) => {
                if (!selecting || mouse.button !== Qt.LeftButton) return
                selecting = false

                // Get geometry relative to the overlay (full-screen)
                var x = Math.round(selectionRect.x)
                var y = Math.round(selectionRect.y)
                var w = Math.round(selectionRect.width)
                var h = Math.round(selectionRect.height)

                // Hide the overlay first so it doesn't appear in the screenshot
                hideRegionSelector()

                if (w < 5 || h < 5) {
                    root.screenshotFailed("Region too small")
                    return
                }

                var geometry = x + "," + y + " " + w + "x" + h
                captureRegionWithGeometry(geometry)
            }

            onCanceled: {
                selecting = false
                hideRegionSelector()
            }
        }

        Keys.onEscapePressed: {
            hideRegionSelector()
        }
    }

    // Capture a region with the given geometry (already in screen coordinates)
    function captureRegionWithGeometry(geometry) {
        var temp = "/tmp/qs-region-" + Date.now() + ".png"
        regionGrimProc._tempPath = temp
        regionGrimProc.command = ["grim", "-g", geometry, temp]
        regionGrimProc.running = false
        regionGrimProc.running = true
    }

    Process {
        id: regionGrimProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0) {
                root.finalizeImage(_tempPath)
            } else {
                root.screenshotFailed("grim region screenshot failed (exit " + code + ")")
            }
        }
    }

    // --- Background capture (unchanged) ---
    function captureFullForBackground() {
        bgMonitorInfoProc.running = false
        bgMonitorInfoProc.running = true
    }

    Process {
        id: bgMonitorInfoProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var outputName = ""
                try {
                    var monitors = JSON.parse(text)
                    var focused = monitors.find(function(m) { return m.focused })
                    outputName = focused ? focused.name : (monitors.length ? monitors[0].name : "")
                } catch (e) {
                    console.warn("[Screenshot] Failed to parse hyprctl monitors output:", e)
                }
                if (!outputName) {
                    root.screenshotFailed("background: could not determine focused output")
                    return
                }
                grimBgProc.command = ["grim", "-o", outputName, "/tmp/qs-bg.png"]
                grimBgProc.running = false
                grimBgProc.running = true
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[Screenshot] hyprctl monitors failed (exit code " + code + ")")
                root.screenshotFailed("background: hyprctl monitors failed (exit " + code + ")")
            }
        }
    }

    Process {
        id: grimBgProc
        onExited: (code, status) => {
            if (code === 0) {
                root.backgroundCaptured("/tmp/qs-bg.png")
            } else {
                console.warn("[Screenshot] grim background capture failed (exit code " + code + ")")
                root.screenshotFailed("grim background capture failed (exit " + code + ")")
            }
        }
    }

    // --- Full screenshot ---
    function captureFull() {
        var temp = "/tmp/qs-full-" + Date.now() + ".png"
        grimFullProc._tempPath = temp
        grimFullProc.command = ["grim", temp]
        grimFullProc.running = false
        grimFullProc.running = true
    }

    Process {
        id: grimFullProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0) {
                root.finalizeImage(_tempPath)
            } else {
                root.screenshotFailed("grim full screenshot failed (exit " + code + ")")
            }
        }
    }

    // --- Monitor screenshot ---
    function captureMonitor() {
        monitorShotInfoProc.running = false
        monitorShotInfoProc.running = true
    }

    Process {
        id: monitorShotInfoProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var outputName = ""
                try {
                    var monitors = JSON.parse(text)
                    var focused = monitors.find(function(m) { return m.focused })
                    outputName = focused ? focused.name : (monitors.length ? monitors[0].name : "")
                } catch (e) {
                    console.warn("[Screenshot] Failed to parse hyprctl monitors output:", e)
                }
                if (!outputName) {
                    root.screenshotFailed("monitor: could not determine focused output")
                    return
                }
                var temp = "/tmp/qs-monitor-" + Date.now() + ".png"
                grimMonitorProc._tempPath = temp
                grimMonitorProc.command = ["grim", "-o", outputName, temp]
                grimMonitorProc.running = false
                grimMonitorProc.running = true
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.screenshotFailed("monitor: hyprctl monitors failed (exit " + code + ")")
            }
        }
    }

    Process {
        id: grimMonitorProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0) {
                root.finalizeImage(_tempPath)
            } else {
                root.screenshotFailed("grim monitor screenshot failed (exit " + code + ")")
            }
        }
    }

    // --- Window screenshot ---
    function captureWindow() {
        windowInfoProc.running = false
        windowInfoProc.running = true
    }

    Process {
        id: windowInfoProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var geom = ""
                try {
                    var win = JSON.parse(text)
                    if (win && win.at && win.size) {
                        geom = win.at[0] + "," + win.at[1] + " " + win.size[0] + "x" + win.size[1]
                    }
                } catch (e) {
                    console.warn("[Screenshot] Failed to parse active window info:", e)
                }
                if (!geom || geom === "0,0 0x0") {
                    root.screenshotFailed("No active window detected")
                    return
                }
                var temp = "/tmp/qs-window-" + Date.now() + ".png"
                grimWindowProc._tempPath = temp
                grimWindowProc.command = ["grim", "-g", geom, temp]
                grimWindowProc.running = false
                grimWindowProc.running = true
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.screenshotFailed("hyprctl activewindow failed (exit " + code + ")")
            }
        }
    }

    Process {
        id: grimWindowProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0) {
                root.finalizeImage(_tempPath)
            } else {
                root.screenshotFailed("grim window screenshot failed (exit " + code + ")")
            }
        }
    }

    // --- Color picker (kept as before; it works) ---
    function pickColor() {
        colorSelectProc.running = false
        colorSelectProc.running = true
    }

    Process {
        id: colorSelectProc
        command: ["sh", "-c", "grim -g \"$(slurp -p -b '#00000044')\" -t ppm - | magick - -format '%[pixel:p{0,0}]' txt:- | grep -E -o '#[0-9A-Fa-f]{6}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var hex = text.trim()
                if (hex) {
                    root.colorPicked(hex)
                    copyTextProc.command = ["wl-copy", hex]
                    copyTextProc.running = false
                    copyTextProc.running = true
                    colorNotifyProc.command = ["notify-send", "Color Picked", hex + " copied to clipboard."]
                    colorNotifyProc.running = false
                    colorNotifyProc.running = true
                } else {
                    root.screenshotFailed("Color picker: no color captured")
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.screenshotFailed("Color picker failed (exit " + code + ")")
            }
        }
    }

    // --- Shared helper processes ---
    Process {
        id: copyImageProc
        onExited: (code, status) => {
            if (code === 0) console.log("[Screenshot] Image copied to clipboard")
            else console.warn("[Screenshot] Clipboard copy failed (exit " + code + ")")
        }
    }

    Process {
        id: copyTextProc
        onExited: (code, status) => {
            if (code === 0) console.log("[ColorPicker] Color copied to clipboard")
        }
    }

    Process {
        id: saveImageProc
        onExited: (code, status) => {
            if (code === 0) console.log("[Screenshot] Saved and notification sent")
            else console.warn("[Screenshot] Save/notify failed (exit " + code + ")")
        }
    }

    Process {
        id: colorNotifyProc
        onExited: (code, status) => {
            if (code === 0) console.log("[ColorPicker] Notification sent")
            else console.warn("[ColorPicker] Notification failed (exit " + code + ")")
        }
    }
}
