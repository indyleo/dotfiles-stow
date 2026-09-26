import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property int intervalSeconds: 900
    property int transitionDurationMs: 1300

    property string lastWallpaper: ""

    // monitor name -> wallpaper path
    property var wallpaperPaths: ({})

    // Use Quickshell's actual screens as the source of truth.
    readonly property var screens: Quickshell.screens

    readonly property string findExpr:
        'find "$DIR" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \\)'

    function _expandHome(p) {
        const home = Quickshell.env("HOME") || ""
        return p.replace(/^~(?=$|\/)/, home)
    }

    function log(level, msg) {
        const line = `[wallpaper] [${level}] ${msg}`
        if (level === "ERROR" || level === "WARN")
            console.warn(line)
        else
            console.log(line)
    }

    Component.onCompleted: {
        root.log(
            "INFO",
            `Wallpaper cycling starting on '${root.wallpapersDir}'`
        )

        root.random()
        cycleTimer.start()
    }

    // ------------------------------------------------------------
    // Pick wallpapers
    // ------------------------------------------------------------

    property bool _picking: false

    function random() {
        if (!root.screens || root.screens.length === 0) {
            root.log("WARN", "No screens detected.")
            return
        }

        const dir = root._expandHome(root.wallpapersDir)

        // Ask one process for a shuffled list of wallpapers.
        pickProc.command = [
            "sh",
            "-c",
            `DIR="$1"; ${root.findExpr} | shuf`,
            "--",
            dir
        ]

        pickProc.running = false
        pickProc.running = true
    }

    Process {
        id: pickProc

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (!text) {
                    root.log(
                        "ERROR",
                        `No images found under ${root.wallpapersDir}`
                    )
                    return
                }

                const images = text
                    .split("\n")
                    .map(x => x.trim())
                    .filter(x => x.length > 0)

                const screens = root.screens

                let newPaths = {}

                // Each monitor gets a different shuffled image.
                //
                // If there are more monitors than wallpapers, we
                // eventually reuse wallpapers.
                for (let i = 0; i < screens.length; ++i) {
                    const screen = screens[i]
                    const image = images[i % images.length]

                    newPaths[screen.name] = "file://" + image

                    root.log(
                        "INFO",
                        `[${screen.name}] -> ${image}`
                    )
                }

                root.wallpaperPaths = newPaths

                if (images.length > 0)
                    root.lastWallpaper = images[0]
            }
        }
    }

    // ------------------------------------------------------------
    // Timer
    // ------------------------------------------------------------

    Timer {
        id: cycleTimer
        interval: root.intervalSeconds * 1000
        repeat: true
        onTriggered: root.random()
    }

    // ------------------------------------------------------------
    // One wallpaper window per monitor
    // ------------------------------------------------------------

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wpWindow

            required property var modelData

            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "black"

            property string targetSrc:
                root.wallpaperPaths[modelData.name] || ""

            property bool activeIsA: true

            onTargetSrcChanged: {
                if (targetSrc === "")
                    return

                if (activeIsA)
                    imgB.source = targetSrc
                else
                    imgA.source = targetSrc
            }

            Image {
                id: imgA

                anchors.fill: parent

                // Equivalent to a full-screen crop/cover:
                // preserve aspect ratio and fill the entire monitor.
                fillMode: Image.PreserveAspectCrop

                asynchronous: true
                cache: true

                opacity: wpWindow.activeIsA ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.transitionDurationMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onStatusChanged: {
                    if (
                        status === Image.Ready &&
                        !wpWindow.activeIsA
                    ) {
                        wpWindow.activeIsA = true
                    }
                }
            }

            Image {
                id: imgB

                anchors.fill: parent

                fillMode: Image.PreserveAspectCrop

                asynchronous: true
                cache: true

                opacity: wpWindow.activeIsA ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.transitionDurationMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onStatusChanged: {
                    if (
                        status === Image.Ready &&
                        wpWindow.activeIsA
                    ) {
                        wpWindow.activeIsA = false
                    }
                }
            }
        }
    }
}
