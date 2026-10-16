import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtMultimedia

Item {
    id: root

    // ------------------------------------------------------------
    // Config
    // ------------------------------------------------------------

    // "pictures" | "videos" | "wallpaper-engine" | "life-wallpaper"
    property string wallpaperMode: "pictures"

    property string baseDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // Optional postfix under baseDir, e.g. "gruvbox", "nord", or a
    // nested path like "other/video". Leave blank to scan baseDir
    // itself. Leading/trailing slashes are stripped automatically.
    property string subDir: ""

    // default transition/interval
    property int intervalSeconds: 900
    property int transitionDurationMs: 1300

    // set default for wallpaper engine
    property string fpsWall: "60"

    // monitor name -> file:// URI (pictures & videos modes)
    property var wallpaperPaths: ({})

    // monitor name -> Workshop ID (wallpaper-engine mode)
    property var wallpaperEngineIds: ({})

    // Optional life-wallpaper preset (default | ambient | matrix-rain |
    // neon-brain | minimal). Empty = use ~/.config/life-wallpaper/config.toml
    property string lifePreset: ""

    // Optional extra CLI args appended to every life-wallpaper invocation,
    // e.g. ["--no-stamps", "--color", "green"]
    property var lifeExtraArgs: []

    property bool engineChecked: false
    property bool engineAvailable: false

    property bool lifeChecked: false
    property bool lifeAvailable: false

    // Bumped by _pickLife() to force the life-wallpaper Variants
    // delegates to restart their processes on demand.
    property int lifeTick: 0

    // Use Quickshell's actual screens as the source of truth.
    readonly property var screens: Quickshell.screens

    readonly property string pictureFindExpr: 'find "$DIR" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \\)'

    readonly property string videoFindExpr: 'find "$DIR" -type f \\( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \\)'

    // set right before pickProc runs, used only for log messages once
    // the async result comes back.
    property string _lastScanDir: ""

    function _expandHome(p) {
        const home = Quickshell.env("HOME") || "";
        return p.replace(/^~(?=$|\/)/, home);
    }

    // Resolves baseDir (+ optional subDir) into the actual directory
    // to scan / look for wallpaper-engine.txt in. Blank subDir just
    // returns baseDir unchanged.
    function _contentDir() {
        const base = root._expandHome(root.baseDir);
        const sub = root.subDir.replace(/^\/+|\/+$/g, "");
        return sub === "" ? base : base + "/" + sub;
    }

    function log(level, msg) {
        const line = `[wallpaper] [${level}] ${msg}`;
        if (level === "ERROR" || level === "WARN")
            console.warn(line);
        else
            console.log(line);
    }

    Component.onCompleted: {
        if (["pictures", "videos", "wallpaper-engine", "life-wallpaper"].indexOf(root.wallpaperMode) === -1) {
            root.log("ERROR", `Invalid wallpaperMode '${root.wallpaperMode}' - expected 'pictures', 'videos', 'wallpaper-engine' or 'life-wallpaper'`);
        }

        const subDirNote = root.subDir === "" ? "no subDir set, scanning baseDir directly" : `subDir: '${root.subDir}'`;

        root.log("INFO", `Wallpaper cycling starting in '${root.wallpaperMode}' mode on '${root._contentDir()}' (${subDirNote})`);

        engineCheckProc.running = true;
        lifeCheckProc.running = true;

        root.random();
        // cycleTimer.start() is intentionally NOT called here.
        // Its `running:` binding below decides whether it ticks.
    }

    // Mode changed at runtime (not the common case, but supported):
    // re-pick immediately so the right map gets populated and any
    // engine processes for the old mode get torn down.
    onWallpaperModeChanged: root.random()

    // ------------------------------------------------------------
    // Pick wallpapers - dispatches by mode
    // ------------------------------------------------------------

    function random() {
        if (!root.screens || root.screens.length === 0) {
            root.log("WARN", "No screens detected.");
            return;
        }

        switch (root.wallpaperMode) {
        case "pictures":
            root._pickMedia(root.pictureFindExpr);
            break;
        case "videos":
            root._pickMedia(root.videoFindExpr);
            break;
        case "wallpaper-engine":
            root._pickEngine();
            break;
        case "life-wallpaper":
            root._pickLife();
            break;
        default:
            root.log("ERROR", `Unknown wallpaperMode '${root.wallpaperMode}'`);
        }
    }

    // ------------------------------------------------------------
    // pictures / videos: scan baseDir directly. The two modes never
    // mix because each one's find expression only matches its own
    // extensions (jpg/png/... vs mp4/webm/...), regardless of what
    // else lives in the directory. Point baseDir at whatever folder
    // actually holds your files for the active mode - it does not
    // need a "pictures" or "videos" subfolder.
    // ------------------------------------------------------------

    function _pickMedia(findExpr) {
        const dir = root._contentDir();
        root._lastScanDir = dir;

        pickProc.command = ["sh", "-c", `DIR="$1"; ${findExpr} | shuf`, "--", dir];

        pickProc.running = false;
        pickProc.running = true;
    }

    Process {
        id: pickProc

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();

                if (!text) {
                    root.log("ERROR", `No ${root.wallpaperMode} files found under ${root._lastScanDir}`);
                    return;
                }

                const files = text.split("\n").map(x => x.trim()).filter(x => x.length > 0);

                const screens = root.screens;
                let newPaths = {};

                // Each monitor gets a different shuffled file. If there
                // are more monitors than files, files get reused.
                for (let i = 0; i < screens.length; ++i) {
                    const screen = screens[i];
                    const file = files[i % files.length];

                    newPaths[screen.name] = "file://" + file;

                    root.log("INFO", `[${screen.name}] -> ${file}`);
                }

                root.wallpaperPaths = newPaths;
            }
        }
    }

    // ------------------------------------------------------------
    // wallpaper-engine: read baseDir/wallpaper-engine.txt, one
    // Workshop ID per line, '#' comments and blank lines ignored.
    // ------------------------------------------------------------

    function _pickEngine() {
        const file = root._contentDir() + "/wallpaper-engine.txt";
        root._lastScanDir = file;

        engineProc.command = ["sh", "-c", 'cat "$1" 2>/dev/null | grep -v "^[[:space:]]*#" | grep -v "^[[:space:]]*$" | shuf', "--", file];

        engineProc.running = false;
        engineProc.running = true;
    }

    Process {
        id: engineProc

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();

                if (!text) {
                    root.log("ERROR", `No Workshop IDs found in ${root._lastScanDir}`);
                    root.wallpaperEngineIds = {};
                    return;
                }

                const ids = text.split("\n").map(x => x.trim()).filter(x => x.length > 0);

                const screens = root.screens;
                let newIds = {};

                for (let i = 0; i < screens.length; ++i) {
                    const screen = screens[i];
                    const id = ids[i % ids.length];

                    newIds[screen.name] = id;

                    root.log("INFO", `[${screen.name}] -> workshop id ${id}`);
                }

                root.wallpaperEngineIds = newIds;
            }
        }
    }

    // ------------------------------------------------------------
    // life-wallpaper: no files to scan. Bumping lifeTick forces
    // the Variants delegates below to restart their processes, so
    // the "random" IPC action becomes a "restart the simulation"
    // action in this mode.
    // ------------------------------------------------------------

    function _pickLife() {
        root.lifeTick++;
    }

    Process {
        id: engineCheckProc
        command: ["sh", "-c", "command -v linux-wallpaperengine >/dev/null 2>&1 && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.engineChecked = true;
                root.engineAvailable = this.text.trim() === "yes";

                if (!root.engineAvailable) {
                    root.log("WARN", "linux-wallpaperengine not found on PATH - wallpaper-engine mode will not launch backgrounds");
                }
            }
        }
    }

    Process {
        id: lifeCheckProc
        command: ["sh", "-c", "command -v life-wallpaper >/dev/null 2>&1 && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.lifeChecked = true;
                root.lifeAvailable = this.text.trim() === "yes";

                if (!root.lifeAvailable) {
                    root.log("WARN", "life-wallpaper not found on PATH - life-wallpaper mode will not launch backgrounds");
                }
            }
        }
    }

    // ------------------------------------------------------------
    // Timer
    //
    // Runs in every mode that should cycle its wallpaper every
    // intervalSeconds:
    //   - pictures / videos: pick a new random file
    //   - wallpaper-engine:  pick a new random Workshop ID and
    //                        restart the engine process on each
    //                        monitor
    //
    // Does NOT run in life-wallpaper mode: the binary manages its
    // own lifetime internally (soft_reset_secs in its config.toml)
    // and killing/relaunching it every interval would cause a
    // visible black flash and reset the generation counter.
    // ------------------------------------------------------------

    Timer {
        id: cycleTimer
        interval: root.intervalSeconds * 1000
        repeat: true
        running: root.wallpaperMode !== "life-wallpaper"
        onTriggered: root.random()
    }

    // ------------------------------------------------------------
    // wallpaper-engine: one linux-wallpaperengine process per
    // monitor, owning its own Wayland background surface. Quickshell
    // never draws into it directly.
    // ------------------------------------------------------------

    Variants {
        model: root.screens

        Item {
            id: engineDelegate

            required property var modelData
            readonly property string screenName: modelData.name
            readonly property string engineId: root.wallpaperEngineIds[screenName] || ""

            function apply() {
                if (root.wallpaperMode !== "wallpaper-engine" || engineId === "" || !root.engineAvailable) {
                    if (proc.running)
                        proc.running = false;
                    return;
                }

                proc.command = ["linux-wallpaperengine", "--screen-root", screenName, "--bg", engineId, "--fps", fpsWall, "--scaling", "fill", "--disable-mouse", "--silent"];

                // Force a restart even if it's already running the
                // previous id, same pattern as pickProc above.
                proc.running = false;
                proc.running = true;
            }

            onEngineIdChanged: apply()
            Component.onCompleted: apply()

            Connections {
                target: root
                function onWallpaperModeChanged() {
                    engineDelegate.apply();
                }
                function onEngineAvailableChanged() {
                    engineDelegate.apply();
                }
            }

            Process {
                id: proc
            }
        }
    }

    // ------------------------------------------------------------
    // life-wallpaper: one life-wallpaper process per monitor,
    // owning its own Wayland background surface. Quickshell never
    // draws into it directly.
    //
    // life-wallpaper supports a single --output NAME, so we launch
    // one process per screen with --output <screenName>. If the
    // binary is missing, we degrade to a no-op instead of spamming
    // the log every tick.
    // ------------------------------------------------------------

    Variants {
        model: root.screens

        Item {
            id: lifeDelegate

            required property var modelData
            readonly property string screenName: modelData.name

            function apply() {
                if (root.wallpaperMode !== "life-wallpaper" || !root.lifeAvailable || !root.lifeChecked) {
                    if (proc.running)
                        proc.running = false;
                    return;
                }

                const args = ["life-wallpaper"];
                if (root.lifePreset !== "")
                    args.push("--preset", root.lifePreset);
                args.push("--output", screenName);
                for (let i = 0; i < root.lifeExtraArgs.length; ++i)
                    args.push(String(root.lifeExtraArgs[i]));

                proc.command = args;

                // Force a restart even if already running.
                proc.running = false;
                proc.running = true;
            }

            Component.onCompleted: apply()

            Connections {
                target: root
                function onWallpaperModeChanged() {
                    lifeDelegate.apply();
                }
                function onLifeAvailableChanged() {
                    lifeDelegate.apply();
                }
                function onLifePresetChanged() {
                    lifeDelegate.apply();
                }
                function onLifeTickChanged() {
                    lifeDelegate.apply();
                }
                function onLifeExtraArgsChanged() {
                    lifeDelegate.apply();
                }
            }

            Process {
                id: proc
                // life-wallpaper writes "config reloaded" / warnings to
                // stderr. Forward them into the Quickshell log so users
                // see them next to the [wallpaper] messages.
                stderr: SplitParser {
                    onRead: line => {
                        const t = line.trim();
                        if (t.length > 0)
                            root.log("INFO", `[life-wallpaper ${screenName}] ${t}`);
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // One wallpaper window per monitor (pictures / videos only).
    // Hidden entirely in wallpaper-engine and life-wallpaper modes
    // so Quickshell's own background layer doesn't fight the
    // external processes' surfaces.
    // ------------------------------------------------------------

    Variants {
        model: root.screens

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

            // Hidden in wallpaper-engine / life-wallpaper modes - no
            // surface fighting the external process's own layer.
            visible: root.wallpaperMode !== "wallpaper-engine" && root.wallpaperMode !== "life-wallpaper"

            property string targetSrc: root.wallpaperPaths[modelData.name] || ""

            onTargetSrcChanged: {
                if (picturesLoader.item)
                    picturesLoader.item.setTarget(targetSrc);
                if (videosLoader.item)
                    videosLoader.item.setTarget(targetSrc);
            }

            Loader {
                id: picturesLoader
                anchors.fill: parent
                active: root.wallpaperMode === "pictures"
                sourceComponent: picturesComponent
                onLoaded: {
                    if (wpWindow.targetSrc !== "")
                        item.setTarget(wpWindow.targetSrc);
                }
            }

            Loader {
                id: videosLoader
                anchors.fill: parent
                active: root.wallpaperMode === "videos"
                sourceComponent: videosComponent
                onLoaded: {
                    if (wpWindow.targetSrc !== "")
                        item.setTarget(wpWindow.targetSrc);
                }
            }
        }
    }

    // ------------------------------------------------------------
    // pictures: A/B crossfading Image pair
    // ------------------------------------------------------------

    Component {
        id: picturesComponent

        Item {
            id: picRoot
            property bool activeIsA: true

            function setTarget(src) {
                if (src === "")
                    return;
                if (activeIsA)
                    imgB.source = src;
                else
                    imgA.source = src;
            }

            Image {
                id: imgA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: picRoot.activeIsA ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.transitionDurationMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onStatusChanged: {
                    if (status === Image.Ready && !picRoot.activeIsA)
                        picRoot.activeIsA = true;
                }
            }

            Image {
                id: imgB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: picRoot.activeIsA ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.transitionDurationMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onStatusChanged: {
                    if (status === Image.Ready && picRoot.activeIsA)
                        picRoot.activeIsA = false;
                }
            }
        }
    }

    // ------------------------------------------------------------
    // videos: A/B crossfading Video pair (Video = MediaPlayer +
    // VideoOutput convenience type). Looping, muted, autoplay.
    // The outgoing player is stopped once its fade-out completes.
    // ------------------------------------------------------------

    Component {
        id: videosComponent

        Item {
            id: vidRoot
            property bool activeIsA: true

            function setTarget(src) {
                if (src === "")
                    return;
                if (activeIsA) {
                    vidB.source = src;
                    vidB.play();
                } else {
                    vidA.source = src;
                    vidA.play();
                }
            }

            Video {
                id: vidA
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                muted: true
                loops: MediaPlayer.Infinite
                opacity: vidRoot.activeIsA ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.transitionDurationMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PlayingState && !vidRoot.activeIsA) {
                        vidRoot.activeIsA = true;
                        stopTimerB.restart();
                    }
                }
            }

            Video {
                id: vidB
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                muted: true
                loops: MediaPlayer.Infinite
                opacity: vidRoot.activeIsA ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.transitionDurationMs
                        easing.type: Easing.InOutQuad
                    }
                }

                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PlayingState && vidRoot.activeIsA) {
                        vidRoot.activeIsA = false;
                        stopTimerA.restart();
                    }
                }
            }

            // Give the fade a moment to finish before killing the
            // outgoing player, so it doesn't cut mid-transition.
            Timer {
                id: stopTimerA
                interval: root.transitionDurationMs + 50
                onTriggered: vidA.stop()
            }
            Timer {
                id: stopTimerB
                interval: root.transitionDurationMs + 50
                onTriggered: vidB.stop()
            }
        }
    }
}
