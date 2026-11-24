import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    screen: PrimaryScreen.screen
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
    signal qrDecoded(string text)
    signal ocrDecoded(string text)

    // Public API
    function screenshotFull() {
        captureFull();
    }
    function screenshotWindow() {
        captureWindow();
    }
    function screenshotMonitor() {
        captureMonitor();
    }
    function screenshotRegion() {
        showRegionSelector();
    }
    function colorPicker() {
        showColorPicker();
    }
    function qrScanner() {
        showQrScanner();
    }
    function ocrScanner() {
        showOcrScanner();
    }

    function getTimestamp() {
        var now = new Date();
        var y = now.getFullYear();
        var mo = String(now.getMonth() + 1).padStart(2, "0");
        var d = String(now.getDate()).padStart(2, "0");
        var h = String(now.getHours()).padStart(2, "0");
        var mi = String(now.getMinutes()).padStart(2, "0");
        var s = String(now.getSeconds()).padStart(2, "0");
        return y + "-" + mo + "-" + d + "_" + h + "-" + mi + "-" + s;
    }

    function finalizeImage(filePath) {
        root.screenshotCaptured(filePath);

        copyImageProc.command = ["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", filePath];
        copyImageProc.running = false;
        copyImageProc.running = true;

        var timestamp = getTimestamp();
        var filename = timestamp + ".png";
        var saveDir = "$HOME/Pictures/Screenshots";

        saveImageProc._filename = filename;
        saveImageProc._saveDir = saveDir;
        saveImageProc.command = ["sh", "-c", "mkdir -p \"" + saveDir + "\" && cp \"$1\" \"" + saveDir + "/$2\"", "sh", filePath, filename];
        saveImageProc.running = false;
        saveImageProc.running = true;
    }

    // --- Selection overlay modes ---
    property string selectorMode: ""   // "region", "color", "qr", "ocr", "ocr-result"
    property string pendingOcrText: ""

    function showRegionSelector() {
        selectorMode = "region";
        root.visible = true;
        selectionRect.visible = false;
        regionMouseArea.selecting = false;
    }

    function showColorPicker() {
        selectorMode = "color";
        root.visible = true;
        selectionRect.visible = false;
        regionMouseArea.selecting = false;
    }

    function showQrScanner() {
        if (!root.zbarAvailable) {
            root.screenshotFailed("QR scanning requires zbarimg (install zbar-tools)");
            return;
        }
        selectorMode = "qr";
        root.visible = true;
        selectionRect.visible = false;
        regionMouseArea.selecting = false;
    }

    property bool ocrLanguageCheckRequested: false

    function beginOcrSelection() {
        selectorMode = "ocr";
        root.visible = true;
        selectionRect.visible = false;
        regionMouseArea.selecting = false;
    }

    function showOcrScanner() {
        if (!root.tesseractAvailable) {
            root.screenshotFailed("OCR requires Tesseract (install tesseract and its language data)");
            return;
        }
        ocrLanguageCheckRequested = true;
        detectOcrLanguageProc.running = false;
        detectOcrLanguageProc.running = true;
    }

    // NEW: show the editable OCR result popup
    function showOcrResult(text) {
        pendingOcrText = text;
        selectorMode = "ocr-result";
        root.visible = true;
        ocrResultText.text = text;
        ocrResultOverlay.forceActiveFocus();
    }

    function hideSelector() {
        selectorMode = "";
        root.visible = false;
        selectionRect.visible = false;
        pendingOcrText = "";
    }

    // Wayland layer-shell surfaces don't unmap synchronously.
    property int hideSettleMs: 60
    property int hideSettleRetries: 3

    Timer {
        id: postHideTimer
        interval: root.hideSettleMs
        repeat: false
        property var pendingCallback: null
        property int attemptsLeft: 0
        onTriggered: {
            if (!pendingCallback)
                return;
            var cb = pendingCallback;
            if (attemptsLeft > 0) {
                attemptsLeft--;
                Qt.callLater(function () {
                    Qt.callLater(function () {
                        postHideTimer.pendingCallback = null;
                        cb();
                    });
                });
            } else {
                pendingCallback = null;
                cb();
            }
        }
    }

    function captureAfterHide(callback) {
        hideSelector();
        postHideTimer.pendingCallback = callback;
        postHideTimer.attemptsLeft = root.hideSettleRetries;
        postHideTimer.restart();
    }

    // --- Region overlay (hidden while the OCR result popup is showing) ---
    Rectangle {
        id: regionOverlay
        anchors.fill: parent
        visible: root.visible && selectorMode !== "ocr-result"
        color: Qt.rgba(0, 0, 0, 0.3)
        focus: true

        Rectangle {
            id: selectionRect
            color: Qt.rgba(1, 1, 1, 0.2)
            border.color: "white"
            border.width: 2
            visible: false
        }

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
            cursorShape: Qt.CrossCursor

            property real startX: 0
            property real startY: 0
            property bool selecting: false

            onPositionChanged: mouse => {
                if (selectorMode === "color") {
                    colorCursor.x = mouse.x;
                    colorCursor.y = mouse.y;
                } else if (selecting) {
                    var x = Math.min(startX, mouse.x);
                    var y = Math.min(startY, mouse.y);
                    var w = Math.abs(mouse.x - startX);
                    var h = Math.abs(mouse.y - startY);
                    selectionRect.x = x;
                    selectionRect.y = y;
                    selectionRect.width = w;
                    selectionRect.height = h;
                }
            }

            onPressed: mouse => {
                if (mouse.button !== Qt.LeftButton)
                    return;
                if (selectorMode === "color") {
                    var x = Math.round(mouse.x);
                    var y = Math.round(mouse.y);
                    root.captureAfterHide(function () {
                        capturePixel(x, y);
                    });
                } else if (selectorMode === "region" || selectorMode === "qr" || selectorMode === "ocr") {
                    selecting = true;
                    startX = mouse.x;
                    startY = mouse.y;
                    selectionRect.x = startX;
                    selectionRect.y = startY;
                    selectionRect.width = 0;
                    selectionRect.height = 0;
                    selectionRect.visible = true;
                }
            }

            onReleased: mouse => {
                if ((selectorMode !== "region" && selectorMode !== "qr" && selectorMode !== "ocr") || !selecting || mouse.button !== Qt.LeftButton)
                    return;
                selecting = false;

                var x = Math.round(selectionRect.x);
                var y = Math.round(selectionRect.y);
                var w = Math.round(selectionRect.width);
                var h = Math.round(selectionRect.height);

                if (w < 5 || h < 5) {
                    hideSelector();
                    root.screenshotFailed("Region too small");
                    return;
                }

                var geometry = x + "," + y + " " + w + "x" + h;

                if (selectorMode === "qr") {
                    root.captureAfterHide(function () {
                        captureQrRegion(geometry);
                    });
                } else if (selectorMode === "ocr") {
                    root.captureAfterHide(function () {
                        captureOcrRegion(geometry);
                    });
                } else {
                    root.captureAfterHide(function () {
                        captureRegionWithGeometry(geometry);
                    });
                }
            }

            onCanceled: {
                selecting = false;
                hideSelector();
            }
        }

        Keys.onEscapePressed: hideSelector()
    }

    // --- OCR result popup (editable, selectable) ---
    // --- OCR result popup (editable, selectable) ---
    Rectangle {
        id: ocrResultOverlay
        anchors.fill: parent
        visible: root.visible && selectorMode === "ocr-result"
        color: Theme.overlayDim
        focus: true

        Keys.onEscapePressed: root.hideSelector()

        MouseArea {
            anchors.fill: parent
            onClicked: root.hideSelector()
        }

        Rectangle {
            id: ocrDialog
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.8, 800)
            height: Math.min(parent.height * 0.8, 600)
            color: Theme.surface
            border.color: Theme.accent
            border.width: 2
            radius: 8

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Extracted Text (editable)"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: 16
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.background
                    border.color: Theme.border
                    border.width: 1
                    radius: 4
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        contentWidth: width
                        contentHeight: ocrResultText.contentHeight
                        clip: true

                        TextEdit {
                            id: ocrResultText
                            width: parent.width
                            color: Theme.text
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 34
                        color: copyMouse.containsMouse ? Theme.buttonHoverBg : Theme.buttonBg
                        radius: 4
                        border.color: Theme.buttonIcon
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Copy"
                            color: Theme.buttonText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        MouseArea {
                            id: copyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                copyTextProc.command = ["wl-copy", "--", ocrResultText.text];
                                copyTextProc.running = false;
                                copyTextProc.running = true;
                                root.hideSelector();
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 34
                        color: closeMouse.containsMouse ? Theme.buttonHoverBg : Theme.buttonBg
                        radius: 4
                        border.color: Theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Close"
                            color: Theme.buttonText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hideSelector()
                        }
                    }
                }
            }
        }
    }

    // --- Region capture ---
    function captureRegionWithGeometry(geometry) {
        var temp = "/tmp/qs-region-" + Date.now() + ".png";
        regionGrimProc._tempPath = temp;
        regionGrimProc.command = ["grim", "-g", geometry, temp];
        regionGrimProc.running = false;
        regionGrimProc.running = true;
    }

    Process {
        id: regionGrimProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0)
                root.finalizeImage(_tempPath);
            else
                root.screenshotFailed("grim region screenshot failed (exit " + code + ")");
        }
    }

    // --- QR capture and decode ---
    function captureQrRegion(geometry) {
        var temp = "/tmp/qs-qr-" + Date.now() + ".png";
        qrGrimProc._tempPath = temp;
        qrGrimProc.command = ["grim", "-g", geometry, temp];
        qrGrimProc.running = false;
        qrGrimProc.running = true;
    }

    Process {
        id: qrGrimProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0) {
                qrDecodeProc._tempPath = _tempPath;
                qrDecodeProc.command = ["zbarimg", "--quiet", "--raw", _tempPath];
                qrDecodeProc.running = false;
                qrDecodeProc.running = true;
            } else {
                root.screenshotFailed("grim QR capture failed (exit " + code + ")");
            }
        }
    }

    Process {
        id: qrDecodeProc
        property string _tempPath
        stdout: StdioCollector {
            onStreamFinished: {
                var decoded = text.trim();
                if (decoded) {
                    root.qrDecoded(decoded);
                    copyTextProc.command = ["wl-copy", decoded];
                    copyTextProc.running = false;
                    copyTextProc.running = true;
                    qrNotifyProc.command = ["notify-send", "QR Code Scanned", decoded + " copied to clipboard."];
                    qrNotifyProc.running = false;
                    qrNotifyProc.running = true;
                } else {
                    root.screenshotFailed("No QR code detected in selection");
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.screenshotFailed("QR decode failed (exit " + code + ")");
        }
    }

    Process {
        id: qrNotifyProc
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("[QR] Notification failed (exit " + code + ")");
        }
    }

    // --- OCR ---
    property string ocrLang: "eng"

    // PSM control:
    //   "auto"   – infer from selection geometry (default)
    //   "line"   – single line      (PSM 7)
    //   "block"  – uniform block    (PSM 6)
    //   "sparse" – sparse text      (PSM 11)
    property string ocrPsmMode: "auto"
    property int ocrPsm: 6           // fallback used only if inference fails

    property bool ocrPreprocess: false
    property int ocrScale: 2
    property int ocrThreshold: 0

    // Infer the appropriate Tesseract PSM for a given selection geometry.
    function inferPsm(geometry) {
        if (root.ocrPsmMode === "line")
            return 7;
        if (root.ocrPsmMode === "block")
            return 6;
        if (root.ocrPsmMode === "sparse")
            return 11;

        if (!geometry)
            return root.ocrPsm;
        var m = geometry.match(/(\d+)x(\d+)/);
        if (!m)
            return root.ocrPsm;

        var w = parseInt(m[1]);
        var h = parseInt(m[2]);

        // Very short selections are almost always a single line.
        if (h <= 40)
            return 7;

        // Wide-and-short rectangles (e.g. code lines, UI labels).
        if (h <= 80 && w > 0 && (w / h) >= 5)
            return 7;

        // Everything else: treat as a block of text.
        return 6;
    }

    // Preprocessing helper. Always runs when ImageMagick is available:
    //   - detects dark backgrounds and negates them (Tesseract needs dark-on-light)
    //   - upscales small text (H < 60 px) so character height is ≥ ~20 px
    // The user's `ocrPreprocess` toggle additionally enables contrast and
    // optional thresholding, and `ocrScale` can override the auto-scale.
    readonly property string ocrPrepScript: `in="$1"; out="$2"; H="$3"; threshold="$4"; uscale="$5"; force_pre="$6"; MBIN="$7"
case "$H" in ''|*[!0-9]*) H=0 ;; esac
SCALE=1
if [ "$H" -gt 0 ] && [ "$H" -lt 60 ]; then
  SCALE=$(( (60 + H - 1) / H ))
  [ "$SCALE" -gt 3 ] && SCALE=3
fi
if [ "$force_pre" = "1" ] && [ "$uscale" -gt "$SCALE" ]; then
  SCALE="$uscale"
fi
MEAN=$("$MBIN" "$in" -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null || echo "0.5")
case "$MEAN" in ''|*[!0-9.]*) MEAN=0.5 ;; esac
ARGS=""
if [ "$SCALE" -gt 1 ]; then
  ARGS="$ARGS -resize $((SCALE * 100))%"
fi
if awk "BEGIN{exit !($MEAN < 0.5)}"; then
  ARGS="$ARGS -negate"
fi
if [ "$force_pre" = "1" ]; then
  ARGS="$ARGS -contrast"
  if [ "$threshold" -gt 0 ]; then
    ARGS="$ARGS -threshold $threshold/255"
  fi
fi
"$MBIN" "$in" -colorspace Gray $ARGS "$out"
`

    function captureOcrRegion(geometry) {
        var temp = "/tmp/qs-ocr-" + Date.now() + ".png";
        ocrGrimProc._tempPath = temp;
        ocrGrimProc._geometry = geometry;
        ocrGrimProc.command = ["grim", "-g", geometry, temp];
        ocrGrimProc.running = false;
        ocrGrimProc.running = true;
    }

    function runOcrOn(path, geometry) {
        var psm = root.inferPsm(geometry);
        ocrProc._output = "";
        ocrProc.command = ["tesseract", path, "stdout", "-l", root.ocrLang, "--psm", String(psm), "--oem", "1", "-c", "preserve_interword_spaces=1"];
        ocrProc.running = false;
        ocrProc.running = true;
    }

    Process {
        id: ocrGrimProc
        property string _tempPath: ""
        property string _geometry: ""
        onExited: (code, status) => {
            if (code !== 0) {
                root.screenshotFailed("grim OCR capture failed (exit " + code + ")");
                return;
            }

            if (root.magickBin === "none") {
                // No ImageMagick available: skip preprocessing, accept lower accuracy.
                ocrProc._tempPath = _tempPath;
                ocrProc._processedPath = "";
                root.runOcrOn(_tempPath, _geometry);
                return;
            }

            var processed = "/tmp/qs-ocr-processed-" + Date.now() + ".png";
            var h = 0;
            var m = _geometry.match(/x(\d+)/);
            if (m)
                h = parseInt(m[1]);

            ocrPrepProc._tempPath = _tempPath;
            ocrPrepProc._processedPath = processed;
            ocrPrepProc._geometry = _geometry;
            ocrPrepProc.command = ["sh", "-c", root.ocrPrepScript, "sh", _tempPath, processed, String(h), String(root.ocrThreshold), String(root.ocrScale), root.ocrPreprocess ? "1" : "0", root.magickBin];
            ocrPrepProc.running = false;
            ocrPrepProc.running = true;
        }
    }

    Process {
        id: ocrPrepProc
        property string _tempPath: ""
        property string _processedPath: ""
        property string _geometry: ""
        onExited: (code, status) => {
            if (code === 0) {
                ocrProc._tempPath = _tempPath;
                ocrProc._processedPath = _processedPath;
                root.runOcrOn(_processedPath, _geometry);
            } else {
                console.warn("[OCR] Preprocessing failed, using raw image");
                cleanupOcrProc.removeFiles(_processedPath, "");
                ocrProc._tempPath = _tempPath;
                ocrProc._processedPath = "";
                root.runOcrOn(_tempPath, _geometry);
            }
        }
    }

    Process {
        id: ocrProc
        property string _tempPath: ""
        property string _processedPath: ""
        property string _output: ""
        stdout: StdioCollector {
            onStreamFinished: ocrProc._output = text
        }
        onExited: (code, status) => {
            if (code === 0) {
                var extracted = ocrProc._output.replace(/\f/g, "").trim();
                if (extracted) {
                    root.ocrDecoded(extracted);
                    // Convenience: seed the clipboard with the raw text.
                    // The popup lets the user review/edit and re-copy.
                    copyTextProc.command = ["wl-copy", "--", extracted];
                    copyTextProc.running = false;
                    copyTextProc.running = true;
                    root.showOcrResult(extracted);
                } else {
                    root.screenshotFailed("No text detected in selection");
                }
            } else {
                root.screenshotFailed("OCR failed (exit " + code + ") - check that the selected language pack is installed");
            }
            cleanupOcrProc.removeFiles(_tempPath, _processedPath);
            _tempPath = "";
            _processedPath = "";
        }
    }

    property bool ocrLanguageAvailable: false
    Process {
        id: detectOcrLanguageProc
        command: ["tesseract", "--list-langs"]
        stdout: StdioCollector {
            onStreamFinished: {
                var langs = text.split(/\r?\n/).map(function (v) {
                    return v.trim();
                });
                var requested = root.ocrLang.split("+");
                root.ocrLanguageAvailable = requested.length > 0 && requested.every(function (lang) {
                    return langs.indexOf(lang.trim()) >= 0;
                });
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.ocrLanguageAvailable = false;
            if (root.ocrLanguageCheckRequested) {
                root.ocrLanguageCheckRequested = false;
                if (root.ocrLanguageAvailable)
                    root.beginOcrSelection();
                else
                    root.screenshotFailed("OCR language pack not detected: " + root.ocrLang + " (install the matching Tesseract traineddata)");
            }
        }
    }

    Process {
        id: cleanupOcrProc
        function removeFiles(path1, path2) {
            var paths = [];
            if (path1)
                paths.push(path1);
            if (path2)
                paths.push(path2);
            if (!paths.length)
                return;
            command = ["rm", "-f"].concat(paths);
            running = false;
            running = true;
        }
    }

    property bool tesseractAvailable: false
    Process {
        id: detectTesseractProc
        running: true
        command: ["sh", "-c", "command -v tesseract >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.tesseractAvailable = (text.trim() === "yes");
                if (!root.tesseractAvailable)
                    console.warn("[Screenshot] tesseract not found - OCR will be unavailable");
            }
        }
    }

    // --- ImageMagick detection ---
    property string magickBin: "magick"
    Process {
        id: detectMagickProc
        running: true
        command: ["sh", "-c", "command -v magick >/dev/null 2>&1 && echo magick || { command -v convert >/dev/null 2>&1 && echo convert || echo none; }"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.magickBin = text.trim();
                if (root.magickBin === "none")
                    console.warn("[Screenshot] Neither 'magick' nor 'convert' found - color picker and OCR preprocessing will be unavailable");
            }
        }
    }

    // --- zbarimg detection ---
    property bool zbarAvailable: false
    Process {
        id: detectZbarProc
        running: true
        command: ["sh", "-c", "command -v zbarimg >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.zbarAvailable = (text.trim() === "yes");
                if (!root.zbarAvailable)
                    console.warn("[Screenshot] zbarimg not found - QR scanning will be unavailable");
            }
        }
    }

    // --- Color picker ---
    function capturePixel(x, y) {
        if (root.magickBin === "none") {
            root.screenshotFailed("Color picker requires ImageMagick (magick or convert), which isn't installed");
            return;
        }
        colorPixelProc.command = ["sh", "-c", "grim -g '" + x + "," + y + " 1x1' -t ppm - | " + root.magickBin + " - -format '%[pixel:p{0,0}]' txt:- | grep -E -o '#[0-9A-Fa-f]{6}'"];
        colorPixelProc.running = false;
        colorPixelProc.running = true;
    }

    Process {
        id: colorPixelProc
        stdout: StdioCollector {
            onStreamFinished: {
                var hex = text.trim();
                if (hex) {
                    root.colorPicked(hex);
                    copyTextProc.command = ["wl-copy", hex];
                    copyTextProc.running = false;
                    copyTextProc.running = true;
                    colorNotifyProc.command = ["notify-send", "Color Picked", hex + " copied to clipboard."];
                    colorNotifyProc.running = false;
                    colorNotifyProc.running = true;
                } else {
                    root.screenshotFailed("Color picker: no color captured");
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.screenshotFailed("Color picker failed (exit " + code + ")");
        }
    }

    // --- Background capture ---
    function captureFullForBackground() {
        bgMonitorInfoProc.running = false;
        bgMonitorInfoProc.running = true;
    }

    Process {
        id: bgMonitorInfoProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var outputName = "";
                try {
                    var monitors = JSON.parse(text);
                    var focused = monitors.find(function (m) {
                        return m.focused;
                    });
                    outputName = focused ? focused.name : (monitors.length ? monitors[0].name : "");
                } catch (e) {
                    console.warn("[Screenshot] Failed to parse hyprctl monitors output:", e);
                }
                if (!outputName) {
                    root.screenshotFailed("background: could not determine focused output");
                    return;
                }
                grimBgProc.command = ["grim", "-o", outputName, "/tmp/qs-bg.png"];
                grimBgProc.running = false;
                grimBgProc.running = true;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[Screenshot] hyprctl monitors failed (exit code " + code + ")");
                root.screenshotFailed("background: hyprctl monitors failed (exit " + code + ")");
            }
        }
    }

    Process {
        id: grimBgProc
        onExited: (code, status) => {
            if (code === 0)
                root.backgroundCaptured("/tmp/qs-bg.png");
            else {
                console.warn("[Screenshot] grim background capture failed (exit code " + code + ")");
                root.screenshotFailed("grim background capture failed (exit " + code + ")");
            }
        }
    }

    // --- Full screenshot ---
    function captureFull() {
        var temp = "/tmp/qs-full-" + Date.now() + ".png";
        grimFullProc._tempPath = temp;
        grimFullProc.command = ["grim", temp];
        grimFullProc.running = false;
        grimFullProc.running = true;
    }

    Process {
        id: grimFullProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0)
                root.finalizeImage(_tempPath);
            else
                root.screenshotFailed("grim full screenshot failed (exit " + code + ")");
        }
    }

    // --- Monitor screenshot ---
    function captureMonitor() {
        monitorShotInfoProc.running = false;
        monitorShotInfoProc.running = true;
    }

    Process {
        id: monitorShotInfoProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var outputName = "";
                try {
                    var monitors = JSON.parse(text);
                    var focused = monitors.find(function (m) {
                        return m.focused;
                    });
                    outputName = focused ? focused.name : (monitors.length ? monitors[0].name : "");
                } catch (e) {
                    console.warn("[Screenshot] Failed to parse hyprctl monitors output:", e);
                }
                if (!outputName) {
                    root.screenshotFailed("monitor: could not determine focused output");
                    return;
                }
                var temp = "/tmp/qs-monitor-" + Date.now() + ".png";
                grimMonitorProc._tempPath = temp;
                grimMonitorProc.command = ["grim", "-o", outputName, temp];
                grimMonitorProc.running = false;
                grimMonitorProc.running = true;
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.screenshotFailed("monitor: hyprctl monitors failed (exit " + code + ")");
        }
    }

    Process {
        id: grimMonitorProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0)
                root.finalizeImage(_tempPath);
            else
                root.screenshotFailed("grim monitor screenshot failed (exit " + code + ")");
        }
    }

    // --- Window screenshot ---
    function captureWindow() {
        windowInfoProc.running = false;
        windowInfoProc.running = true;
    }

    Process {
        id: windowInfoProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var geom = "";
                try {
                    var win = JSON.parse(text);
                    if (win && win.at && win.size) {
                        geom = win.at[0] + "," + win.at[1] + " " + win.size[0] + "x" + win.size[1];
                    }
                } catch (e) {
                    console.warn("[Screenshot] Failed to parse active window info:", e);
                }
                if (!geom || geom === "0,0 0x0") {
                    root.screenshotFailed("No active window detected");
                    return;
                }
                var temp = "/tmp/qs-window-" + Date.now() + ".png";
                grimWindowProc._tempPath = temp;
                grimWindowProc.command = ["grim", "-g", geom, temp];
                grimWindowProc.running = false;
                grimWindowProc.running = true;
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.screenshotFailed("hyprctl activewindow failed (exit " + code + ")");
        }
    }

    Process {
        id: grimWindowProc
        property string _tempPath
        onExited: (code, status) => {
            if (code === 0)
                root.finalizeImage(_tempPath);
            else
                root.screenshotFailed("grim window screenshot failed (exit " + code + ")");
        }
    }

    // --- Shared helper processes ---
    Process {
        id: copyImageProc
        onExited: (code, status) => {
            if (code === 0)
                console.log("[Screenshot] Image copied to clipboard");
            else
                console.warn("[Screenshot] Clipboard copy failed (exit " + code + ")");
        }
    }

    Process {
        id: copyTextProc
        onExited: (code, status) => {
            if (code === 0)
                console.log("[Clipboard] Text copied to clipboard");
        }
    }

    Process {
        id: saveImageProc
        property string _filename: ""
        property string _saveDir: ""
        onExited: (code, status) => {
            if (code === 0) {
                console.log("[Screenshot] Saved to", saveImageProc._saveDir + "/" + saveImageProc._filename);
                saveNotifyProc.command = ["sh", "-c", "notify-send 'Screenshot Captured' \"Saved to: $1\" -i \"" + saveImageProc._saveDir + "/$1\"", "sh", saveImageProc._filename];
                saveNotifyProc.running = false;
                saveNotifyProc.running = true;
            } else {
                console.warn("[Screenshot] Save failed (exit " + code + ")");
                root.screenshotFailed("failed to save screenshot (exit " + code + ")");
            }
        }
    }

    Process {
        id: saveNotifyProc
        onExited: (code, status) => {
            if (code !== 0)
                console.warn("[Screenshot] notify-send failed or is not installed (exit " + code + "); the screenshot was still saved");
        }
    }

    Process {
        id: colorNotifyProc
        onExited: (code, status) => {
            if (code === 0)
                console.log("[ColorPicker] Notification sent");
            else
                console.warn("[ColorPicker] Notification failed (exit " + code + ")");
        }
    }
}
