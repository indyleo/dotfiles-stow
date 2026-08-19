import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal backgroundCaptured(string filePath)
    signal screenshotCaptured(string filePath)
    signal colorPicked(string hexColor)
    signal screenshotFailed(string reason)

    function createToken(prefix) {
        return prefix + "_" + Date.now() + "_" + Math.floor(Math.random() * 10000)
    }

    // --- Public API (user actions) ---
    function screenshotFull()    { requestScreenshot("screen", false) }
    function screenshotWindow()  { requestScreenshot("window", true) }
    function screenshotMonitor() { requestScreenshot("monitor", false) }
    function screenshotRegion()  { requestScreenshot("region", true) }
    function colorPicker()       { requestColor() }

    // --- Background-blur capture: uses grim directly, not the portal ---
    //
    // This deliberately skips org.freedesktop.portal.Screenshot. That call is broken
    // in this environment (XDPH logs the request, then never invokes capture at all,
    // even with --verbose trace logging on - looks like an upstream XDPH bug, not
    // something fixable here). It's also unnecessary for this specific case: the
    // captured image only ever feeds a local blur backdrop behind our own UI, it never
    // leaves the compositor, so there's no reason to route it through portal consent
    // machinery meant for handing screenshots to other (possibly sandboxed) apps.
    // grim talks to the compositor's own wlr-screencopy protocol directly and is
    // confirmed working standalone on this system.
    function captureFullForBackground() {
        monitorInfoProc.running = false
        monitorInfoProc.running = true
    }

    Process {
        id: monitorInfoProc
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

    // --- Everything below still goes through the portal ---
    // (full/window/region screenshots and color picking are user-facing actions
    // where routing through the portal's consent model is the right call - and
    // it's worth re-testing these once the XDPH bug above gets sorted upstream,
    // in case only the non-interactive "background" path is affected.)

    function requestScreenshot(type, interactive) {
        var token = createToken("qs_shot")
        var options = "{'handle_token': <'" + token + "'>, 'type': <'" + type + "'>, 'interactive': <" + interactive + ">, 'modal': <true>}"
        callPortal(shotCall, shotMonitor, options, function(props) {
            var uri = extractUri(props)
            if (uri) {
                var filePath = uri.replace("file://", "")
                root.screenshotCaptured(filePath)
                copyImageProc.command = ["sh", "-c", "wl-copy --type image/png < '" + filePath + "'"]
                copyImageProc.running = false
                copyImageProc.running = true
            } else {
                root.screenshotFailed("screenshot: no uri in portal response")
            }
        })
    }

    function requestColor() {
        var options = "{'handle_token': <'" + createToken("qs_color") + "'>, 'interactive': <true>}"
        callPortal(colorCall, colorMonitor, options, function(props) {
            var colorMatch = props.match(/'color': <\(([^)]+)\)>/)
            if (colorMatch && colorMatch[1]) {
                var parts = colorMatch[1].split(",").map(function(s) { return parseFloat(s.trim()) })
                var r = Math.round(parts[0] * 255)
                var g = Math.round(parts[1] * 255)
                var b = Math.round(parts[2] * 255)
                var hex = "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1).toUpperCase()
                root.colorPicked(hex)
                copyTextProc.command = ["wl-copy", hex]
                copyTextProc.running = false
                copyTextProc.running = true
            } else {
                root.screenshotFailed("color picker: no color in portal response")
            }
        }, "PickColor")
    }

    function extractUri(props) {
        var m = props.match(/'uri': <'([^']+)'/)
        return m ? m[1] : null
    }

    // --- Core: call a portal method, then watch only its own request object ---
    function callPortal(callProc, monitorProc, options, onProps, method) {
        callProc._onProps = onProps
        callProc.command = [
            "gdbus", "call",
            "--session",
            "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop",
            "--method", "org.freedesktop.portal.Screenshot." + (method || "Screenshot"),
            "",
            options
        ]
        callProc._monitor = monitorProc
        callProc.running = false
        callProc.running = true
    }

    function startScopedMonitor(monitorProc, requestPath, onProps) {
        monitorProc._onProps = onProps
        monitorProc.command = ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", requestPath]
        monitorProc.running = false
        monitorProc.running = true
        monitorProc._timeout.restart()
    }

    // --- Screenshot request/response pair ---
    Process {
        id: shotCall
        property var _onProps
        property var _monitor
        stdout: StdioCollector {
            onStreamFinished: {
                var pathMatch = text.match(/objectpath\s+'([^']+)'/)
                if (pathMatch && pathMatch[1]) {
                    root.startScopedMonitor(shotMonitor, pathMatch[1], shotCall._onProps)
                } else {
                    console.warn("[Screenshot] Portal call returned no request handle:", text.trim())
                    root.screenshotFailed("no request handle from portal")
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[Screenshot] Portal Screenshot call failed (exit code " + code + ")")
                root.screenshotFailed("portal call failed (exit " + code + ")")
            }
        }
    }
    Process {
        id: shotMonitor
        property var _onProps
        property Timer _timeout: Timer {
            interval: 30000
            onTriggered: { shotMonitor.running = false; root.screenshotFailed("timed out waiting for portal response") }
        }
        stdout: SplitParser {
            onRead: (line) => {
                if (!line.includes("org.freedesktop.portal.Request.Response")) return
                shotMonitor._timeout.stop()
                shotMonitor.running = false
                shotMonitor._onProps(line)
            }
        }
    }

    // --- Color-picker request/response pair ---
    Process {
        id: colorCall
        property var _onProps
        stdout: StdioCollector {
            onStreamFinished: {
                var pathMatch = text.match(/objectpath\s+'([^']+)'/)
                if (pathMatch && pathMatch[1]) {
                    root.startScopedMonitor(colorMonitor, pathMatch[1], colorCall._onProps)
                } else {
                    root.screenshotFailed("color picker: no request handle from portal")
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[ColorPicker] Portal PickColor call failed (exit code " + code + ")")
                root.screenshotFailed("color picker call failed (exit " + code + ")")
            }
        }
    }
    Process {
        id: colorMonitor
        property var _onProps
        property Timer _timeout: Timer {
            interval: 30000
            onTriggered: { colorMonitor.running = false; root.screenshotFailed("color picker: timed out waiting for portal response") }
        }
        stdout: SplitParser {
            onRead: (line) => {
                if (!line.includes("org.freedesktop.portal.Request.Response")) return
                colorMonitor._timeout.stop()
                colorMonitor.running = false
                colorMonitor._onProps(line)
            }
        }
    }

    // --- Clipboard helpers ---
    Process {
        id: copyImageProc
        onExited: (code, status) => {
            if (code === 0) console.log("[Screenshot] Image copied to clipboard")
        }
    }

    Process {
        id: copyTextProc
        onExited: (code, status) => {
            if (code === 0) console.log("[ColorPicker] Color copied to clipboard")
        }
    }
}
