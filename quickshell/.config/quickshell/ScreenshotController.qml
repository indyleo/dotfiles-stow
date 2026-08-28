import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    // Keep the window hidden normally; it only appears for selection
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
    function colorPicker()       { showColorPicker() }

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

        saveImageProc._filename = filename
        saveImageProc._saveDir = saveDir
        saveImageProc.command = [
            "sh", "-c",
            "mkdir -p \"" + saveDir + "\" && cp \"$1\" \"" + saveDir + "/$2\"",
            "sh",
            filePath,
            filename
        ]
        saveImageProc.running = false
        saveImageProc.running = true
    }

    // --- Selection overlay (region + color) ---
    property string selectorMode: ""   // "region" or "color"

    function showRegionSelector() {
        selectorMode = "region"
        root.visible = true
        selectionRect.visible = false
        regionMouseArea.selecting = false
    }

    function showColorPicker() {
        selectorMode = "color"
        root.visible = true
        selectionRect.visible = false
        regionMouseArea.selecting = false
    }

    function hideSelector() {
        selectorMode = ""
        root.visible = false
        selectionRect.visible = false
    }

    // Wayland layer-shell surfaces don't unmap synchronously when you flip
    // `visible` - the compositor needs to process that and actually
    // recomposite a frame without us in it. Firing grim right after
    // hideSelector() races that, so the overlay (dimming + white selection
    // rect) can still be in the buffer grim reads, producing a white tint
    // on the captured region. This delays the actual capture call until
    // after that unmap has had time to land.
    property int hideSettleMs: 60
    property int hideSettleRetries: 3   // extra safety re-arms if a frame is dropped/delayed

    Timer {
        id: postHideTimer
        interval: root.hideSettleMs
        repeat: false
        property var pendingCallback: null
        property int attemptsLeft: 0
        onTriggered: {
            if (!pendingCallback) return
            var cb = pendingCallback
            // Give the compositor a couple of extra idle passes to actually
            // commit the unmap before we trust it and fire. Cheap insurance
            // against a single dropped/delayed frame; doesn't add real
            // latency since animationFrame ticks are ~16ms.
            if (attemptsLeft > 0) {
                attemptsLeft--
                Qt.callLater(function() {
                    Qt.callLater(function() {
                        postHideTimer.pendingCallback = null
                        cb()
                    })
                })
            } else {
                pendingCallback = null
                cb()
            }
        }
    }

    // Hides the selector overlay, then invokes callback once the compositor
    // has had a chance to actually remove it from the screen. Use this
    // instead of calling hideSelector() immediately followed by a capture.
    function captureAfterHide(callback) {
        hideSelector()
        postHideTimer.pendingCallback = callback
        postHideTimer.attemptsLeft = root.hideSettleRetries
        postHideTimer.restart()
    }

    // Full-screen semi-transparent overlay
    Rectangle {
        id: regionOverlay
        anchors.fill: parent
        visible: root.visible
        color: Qt.rgba(0, 0, 0, 0.3)
        focus: true

        // Rectangle showing the selection (only used in region mode)
        Rectangle {
            id: selectionRect
            color: Qt.rgba(1, 1, 1, 0.2)
            border.color: "white"
            border.width: 2
            visible: false
        }

        // Crosshair cursor indicator (for color mode)
        Rectangle {
            id: colorCursor
            width: 2
            height: 2
            color: "white"
            visible: selectorMode === "color"
            x: -1
            y: -1
        }

        MouseArea {
            id: regionMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: selectorMode === "color" ? Qt.CrossCursor : Qt.CrossCursor

            property real startX: 0
            property real startY: 0
            property bool selecting: false

            // Track mouse position for color cursor
            onPositionChanged: (mouse) => {
                if (selectorMode === "color") {
                    colorCursor.x = mouse.x
                    colorCursor.y = mouse.y
                } else if (selecting) {
                    var x = Math.min(startX, mouse.x)
                    var y = Math.min(startY, mouse.y)
                    var w = Math.abs(mouse.x - startX)
                    var h = Math.abs(mouse.y - startY)

                    selectionRect.x = x
                    selectionRect.y = y
                    selectionRect.width = w
                    selectionRect.height = h
                }
            }

            onPressed: (mouse) => {
                if (mouse.button !== Qt.LeftButton) return

                if (selectorMode === "color") {
                    // Single click: capture pixel under cursor
                    var x = Math.round(mouse.x)
                    var y = Math.round(mouse.y)
                    root.captureAfterHide(function() {
                        capturePixel(x, y)
                    })
                } else if (selectorMode === "region") {
                    selecting = true
                    startX = mouse.x
                    startY = mouse.y
                    selectionRect.x = startX
                    selectionRect.y = startY
                    selectionRect.width = 0
                    selectionRect.height = 0
                    selectionRect.visible = true
                }
            }

            onReleased: (mouse) => {
                if (selectorMode !== "region" || !selecting || mouse.button !== Qt.LeftButton) return
                selecting = false

                // Get geometry relative to the overlay (full-screen)
                var x = Math.round(selectionRect.x)
                var y = Math.round(selectionRect.y)
                var w = Math.round(selectionRect.width)
                var h = Math.round(selectionRect.height)

                if (w < 5 || h < 5) {
                    // Nothing worth capturing - just hide immediately, no
                    // need to wait for compositor settle since we're not
                    // firing grim.
                    hideSelector()
                    root.screenshotFailed("Region too small")
                    return
                }

                var geometry = x + "," + y + " " + w + "x" + h

                // Hide the overlay first, then wait for the compositor to
                // actually settle before capturing, so it doesn't appear
                // (as a white tint) in the screenshot.
                root.captureAfterHide(function() {
                    captureRegionWithGeometry(geometry)
                })
            }

            onCanceled: {
                selecting = false
                hideSelector()
            }
        }

        Keys.onEscapePressed: {
            hideSelector()
        }
    }

    // Capture a region with the given geometry
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

    // ImageMagick 7 renamed its CLI to `magick`; many systems still only
    // have IM6's `convert`. Detect which is available once at startup so
    // the color picker doesn't just fail on IM6-only systems.
    property string magickBin: "magick"

    Process {
        id: detectMagickProc
        running: true
        command: ["sh", "-c",
            "command -v magick >/dev/null 2>&1 && echo magick || " +
            "{ command -v convert >/dev/null 2>&1 && echo convert || echo none; }"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.magickBin = text.trim()
                if (root.magickBin === "none") {
                    console.warn("[Screenshot] Neither 'magick' nor 'convert' found - color picker will not work")
                }
            }
        }
    }

    // Capture a single pixel at (x, y) and extract its color
    function capturePixel(x, y) {
        if (root.magickBin === "none") {
            root.screenshotFailed("Color picker requires ImageMagick (magick or convert), which isn't installed")
            return
        }
        colorPixelProc.command = [
            "sh", "-c",
            "grim -g '" + x + "," + y + " 1x1' -t ppm - | " + root.magickBin + " - -format '%[pixel:p{0,0}]' txt:- | grep -E -o '#[0-9A-Fa-f]{6}'"
        ]
        colorPixelProc.running = false
        colorPixelProc.running = true
    }

    Process {
        id: colorPixelProc
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
        property string _filename: ""
        property string _saveDir: ""
        onExited: (code, status) => {
            if (code === 0) {
                console.log("[Screenshot] Saved to", saveImageProc._saveDir + "/" + saveImageProc._filename)
                saveNotifyProc.command = [
                    "sh", "-c",
                    "notify-send 'Screenshot Captured' \"Saved to: $1\" -i \"" + saveImageProc._saveDir + "/$1\"",
                    "sh",
                    saveImageProc._filename
                ]
                saveNotifyProc.running = false
                saveNotifyProc.running = true
            } else {
                console.warn("[Screenshot] Save failed (exit " + code + ")")
                root.screenshotFailed("failed to save screenshot (exit " + code + ")")
            }
        }
    }

    Process {
        id: saveNotifyProc
        onExited: (code, status) => {
            // Only the notification failed here (e.g. notify-send isn't
            // installed) - the screenshot itself already saved
            // successfully, so this is a soft warning, not a user-facing
            // failure.
            if (code !== 0) console.warn("[Screenshot] notify-send failed or is not installed (exit " + code + "); the screenshot was still saved")
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