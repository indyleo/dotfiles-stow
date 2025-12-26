import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // --- Nord Theme Colors ---
    readonly property color nord0:  "#2e3440"
    readonly property color nord1:  "#3b4252"
    readonly property color nord2:  "#434c5e"
    readonly property color nord3:  "#4c566a"
    readonly property color nord6:  "#eceff4"
    readonly property color nord7:  "#8fbcbb"
    readonly property color nord8:  "#88c0d0"
    readonly property color nord9:  "#81a1c1"
    readonly property color nord10: "#5e81ac"
    readonly property color nord11: "#bf616a"
    readonly property color nord13: "#ebcb8b"
    readonly property color nord14: "#a3be8c"
    readonly property color nord15: "#b48ead"

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13

    // --- Dynamic Window Logic ---
    property string activeWindow: {
        const top = Hyprland.activeToplevel
        const focusedWs = Hyprland.focusedWorkspace
        if (top && focusedWs && top.workspace === focusedWs) {
            return (top.title && top.title.trim() !== "") ? top.title.trim() : "Untitled"
        }
        return "Desktop"
    }

    property string currentLayout: {
        const top = Hyprland.activeToplevel
        const focusedWs = Hyprland.focusedWorkspace
        if (!top || !focusedWs || top.workspace !== focusedWs) return "EMPTY"
        if (top.fullscreen) return "FULLSCREEN"
        if (top.floating) return "FLOATING"
        return "TILED"
    }

    // --- Hardware & System Data ---
    property var lastCpuIdle: 0; property var lastCpuTotal: 0
    property int cpuUsage: 0

    // Memory Properties
    property bool showMemPercent: true
    property int memUsagePercent: 0
    property string memText: "0%"

    // Disk Properties
    property bool showDiskPercent: true
    property var disks: []
    property int currentDiskIdx: 0
    property string diskUsage: "0%"
    property string diskLabel: "/"

    // Audio / Wifi
    property int volumeLevel: 0; property bool isMuted: false
    property int micLevel: 0; property bool isMicMuted: false
    property string kernelVersion: "..."
    property string wifiSSID: "Offline"
    property int wifiStrength: 0

    Process { id: shellCmd }

    Process {
        id: kernelProc
        command: ["uname", "-r"]
        running: true
        stdout: SplitParser { onRead: data => { kernelVersion = data.trim() } }
    }

    // --- Resource Fetchers ---
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(/\s+/)
                var total = parts.slice(1, 8).reduce((a, b) => parseInt(a) + parseInt(b), 0)
                var idle = parseInt(parts[4]) + parseInt(parts[5])
                if (root.lastCpuTotal > 0) {
                    var totalDiff = total - root.lastCpuTotal
                    var idleDiff = idle - root.lastCpuIdle
                    if (totalDiff > 0) cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                }
                root.lastCpuTotal = total; root.lastCpuIdle = idle
            }
        }
    }

    Process {
        id: memProc
        // NEW: Fetch Used and Total in MB (free -m) to allow custom formatting
        command: ["sh", "-c", "free -m | grep Mem | awk '{print $3, $2}'"]
        stdout: SplitParser {
            onRead: d => {
                if(!d) return
                let parts = d.trim().split(" ")
                if (parts.length < 2) return

                let usedMb = parseInt(parts[0])
                let totalMb = parseInt(parts[1])

                // Keep the integer percentage for potential other uses
                root.memUsagePercent = Math.round((usedMb / totalMb) * 100)

                if (root.showMemPercent) {
                    root.memText = root.memUsagePercent + "%"
                } else {
                    let usedGb = (usedMb / 1024).toFixed(1)
                    let totalGb = (totalMb / 1024).toFixed(1)
                    root.memText = usedGb + "G/" + totalGb + "G"
                }
            }
        }
    }

    Process {
        id: diskProc
        // NEW: Added 'used' and 'size' columns to df command
        command: ["sh", "-c", "df -h --output=pcent,used,size,target | grep -E '/$|/home|/mnt|/run/media|/media'"]

        property string outputBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                if (data) diskProc.outputBuffer += data + "\n"
            }
        }

        onExited: {
            if (!diskProc.outputBuffer) return

            let lines = diskProc.outputBuffer.trim().split("\n")
            let parsedDisks = []

            lines.forEach(line => {
                let parts = line.trim().split(/\s+/)
                // Expecting 4 parts: [Percentage, Used, Total, Path]
                if (parts.length >= 4) {
                    let pcent = parts[0]
                    let used = parts[1]
                    let size = parts[2]
                    let pathRaw = parts[3]

                    let label = pathRaw === "/" ? "/" : pathRaw.split('/').pop()

                    parsedDisks.push({
                        pcent: pcent,
                        absolute: used + "/" + size,
                        path: label
                    })
                }
            })

            root.disks = parsedDisks

            // Bounds check
            if (root.currentDiskIdx >= root.disks.length) root.currentDiskIdx = 0

            root.updateDiskText()

            diskProc.outputBuffer = ""
        }
    }

    // Helper to refresh disk text based on current mode
    function updateDiskText() {
        if (root.disks.length > 0) {
            let disk = root.disks[root.currentDiskIdx]
            root.diskLabel = disk.path
            root.diskUsage = root.showDiskPercent ? disk.pcent : disk.absolute
        }
    }

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "active,ssid,signal", "dev", "wifi"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.startsWith("yes")) {
                    let parts = data.trim().split(":");
                    wifiSSID = parts[1] || "Unknown";
                    wifiStrength = parseInt(parts[2]) || 0;
                } else if (!wifiSSID || wifiSSID === "") {
                    wifiSSID = "Offline";
                    wifiStrength = 0;
                }
            }
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var match = data.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
                if (match) {
                    volumeLevel = Math.round(parseFloat(match[1]) * 100)
                    isMuted = !!match[2]
                }
            }
        }
    }

    Process {
        id: micProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: SplitParser {
            onRead: data => {
                var match = data.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
                if (match) {
                    micLevel = Math.round(parseFloat(match[1]) * 100)
                    isMicMuted = !!match[2]
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuProc.running = false; cpuProc.running = true
            memProc.running = false; memProc.running = true
            volProc.running = false; volProc.running = true
            micProc.running = false; micProc.running = true
            wifiProc.running = false; wifiProc.running = true
            diskProc.running = false; diskProc.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 34
            color: root.nord0

            RowLayout {
                anchors.fill: parent
                spacing: 8
                anchors.leftMargin: 12; anchors.rightMargin: 12

                // --- 1. Workspaces ---
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: (26 * 9) + 24
                    color: root.nord1; radius: 13
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Repeater {
                            model: 9
                            Rectangle {
                                width: 24; height: 26; color: "transparent"
                                property var workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
                                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                                property bool hasWindows: workspace !== null
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.isActive ? "" : (parent.hasWindows ? "" : "")
                                    color: parent.isActive ? root.nord8 : (parent.hasWindows ? root.nord9 : root.nord3)
                                    font.pixelSize: parent.isActive ? root.fontSize + 2 : root.fontSize
                                    font.family: root.fontFamily
                                }
                                MouseArea { anchors.fill: parent; onClicked: { Hyprland.dispatch("workspace " + (index + 1)) } }
                            }
                        }
                    }
                }

                // --- 2. Layout Pill ---
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: layoutText.implicitWidth + 24
                    color: root.nord1; radius: 13
                    Text {
                        id: layoutText; anchors.centerIn: parent
                        text: root.currentLayout; color: root.nord7
                        font { pixelSize: root.fontSize - 2; family: root.fontFamily; bold: true }
                    }
                }

                // --- 3. Window Title ---
                Rectangle {
                    Layout.preferredHeight: 26; Layout.fillWidth: true; Layout.minimumWidth: 100
                    color: root.nord1; radius: 13; clip: true
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15
                        spacing: 10
                        Text { text: root.activeWindow === "Desktop" ? "󰇄" : "󱂬"; color: root.nord10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily }
                        Text { Layout.fillWidth: true; text: root.activeWindow; color: root.nord6; font.pixelSize: root.fontSize; font.family: root.fontFamily; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                // --- 4. Stats Pill ---
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: statsRow.implicitWidth + 30
                    color: root.nord1; radius: 13
                    RowLayout {
                        id: statsRow; anchors.centerIn: parent; spacing: 12

                        Text { text: "󰌽 " + kernelVersion; color: root.nord10; font.pixelSize: root.fontSize; font.family: root.fontFamily }
                        Rectangle { width: 1; height: 12; color: root.nord3 }

                        Text { text: " " + cpuUsage + "%"; color: root.nord11; font.pixelSize: root.fontSize; font.family: root.fontFamily }
                        Rectangle { width: 1; height: 12; color: root.nord3 }

                        // --- Memory ---
                        Text {
                            text: " " + root.memText
                            color: root.nord13
                            font.pixelSize: root.fontSize
                            font.family: root.fontFamily
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: {
                                    root.showMemPercent = !root.showMemPercent
                                    // Refresh immediately
                                    memProc.running = false
                                    memProc.running = true
                                }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.nord3 }

                        // --- Disk ---
                        Text {
                            text: "󰋊 " + root.diskLabel + ": " + root.diskUsage
                            color: root.nord7
                            font.pixelSize: root.fontSize
                            font.family: root.fontFamily
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        // Cycle disks
                                        if (root.disks.length > 0) {
                                            root.currentDiskIdx = (root.currentDiskIdx + 1) % root.disks.length;
                                            root.updateDiskText();
                                        }
                                    } else if (mouse.button === Qt.RightButton) {
                                        // Toggle View
                                        root.showDiskPercent = !root.showDiskPercent;
                                        root.updateDiskText();
                                    }
                                }
                            }
                        }
                        Rectangle { width: 1; height: 12; color: root.nord3 }

                        Text {
                            property string icon: {
                                if (root.wifiSSID === "Offline") return "󰤮 ";
                                if (root.wifiStrength > 75) return "󰤨 ";
                                if (root.wifiStrength > 50) return "󰤥 ";
                                if (root.wifiStrength > 25) return "󰤢 ";
                                return "󰤟 ";
                            }
                            text: icon + (root.wifiSSID === "Offline" ? "Searching..." : root.wifiSSID) + " (" + root.wifiStrength + "%)"
                            color: root.wifiSSID === "Offline" ? root.nord11 : root.nord8
                            font.pixelSize: root.fontSize; font.family: root.fontFamily
                        }

                        Rectangle { width: 2; height: 14; color: root.nord2; radius: 1 }

                        Text {
                            text: (root.isMicMuted ? "󰍭 " : "󰍬 ") + micLevel + "%"
                            color: root.isMicMuted ? root.nord3 : root.nord15
                            font.pixelSize: root.fontSize; font.family: root.fontFamily
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onWheel: (w) => {
                                    let isUp = w.angleDelta.y > 0;
                                    if (isUp && root.micLevel >= 100) return;
                                    let dir = isUp ? "5%+" : "5%-";
                                    shellCmd.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", dir];
                                    shellCmd.running = false; shellCmd.running = true;
                                }
                                onClicked: (m) => {
                                    if (m.button === Qt.RightButton) {
                                        shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"];
                                    } else {
                                        shellCmd.command = ["pavucontrol"];
                                    }
                                    shellCmd.running = false; shellCmd.running = true;
                                }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.nord3 }

                        Text {
                            text: (root.isMuted ? "󰝟 " : " ") + volumeLevel + "%"
                            color: root.isMuted ? root.nord3 : root.nord14
                            font.pixelSize: root.fontSize; font.family: root.fontFamily
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onWheel: (w) => {
                                    let isUp = w.angleDelta.y > 0;
                                    if (isUp && root.volumeLevel >= 100) return;
                                    let dir = isUp ? "5%+" : "5%-";
                                    shellCmd.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", dir];
                                    shellCmd.running = false; shellCmd.running = true;
                                }
                                onClicked: (m) => {
                                    if (m.button === Qt.RightButton) {
                                        shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
                                    } else {
                                        shellCmd.command = ["pavucontrol"];
                                    }
                                    shellCmd.running = false; shellCmd.running = true;
                                }
                            }
                        }
                    }
                }

                // --- 5. Clock ---
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: clockText.implicitWidth + 30
                    color: root.nord2; radius: 13
                    Text {
                        id: clockText; anchors.centerIn: parent; property var dateTime: new Date()
                        text: Qt.formatDateTime(dateTime, "󰥔  hh:mm AP |   dddd MMMM dd yyyy")
                        color: root.nord6; font { pixelSize: root.fontSize; family: root.fontFamily; bold: true }
                        Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.dateTime = new Date() }
                    }
                }
            }
        }
    }
}
