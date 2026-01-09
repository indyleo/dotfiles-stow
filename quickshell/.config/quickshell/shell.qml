import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

ShellRoot {
    id: root

    // --- Calamity Theme Colors ---
    readonly property color cal0:  "#0f0f0f" // Deep Void Black (Background)
    readonly property color cal1:  "#1a1a1a" // Dark Charcoal (Pills)
    readonly property color cal2:  "#2d2d2d" // Lighter Charcoal (Primary Pill BG)
    readonly property color cal3:  "#4c1111" // Dried Blood (Muted/Separators)
    readonly property color cal6:  "#f9e5c7" // Auric Silk (Main Text)
    readonly property color cal7:  "#3ec1d3" // Abyss Teal (Integrated GPU / Disk)
    readonly property color cal8:  "#ff4646" // Brimstone Red (Mic/Highlight)
    readonly property color cal9:  "#b45ef7" // Cosmic Purple (Kernel)
    readonly property color cal10: "#df9d1b" // Auric Gold (Wifi)
    readonly property color cal11: "#ff003c" // Profaned Flame (CPU/Alerts)
    readonly property color cal13: "#73f973" // Sulphurous Green (Nvidia GPU / RAM)
    readonly property color cal14: "#ffa500" // Yharon Orange (Audio)
    readonly property color cal15: "#e0e0e0" // Exo Silver (Tech)

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

    // CPU
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0
    property int cpuUsage: 0
    property int cpuTemp: 0
    property bool showCpuTemp: false

    // GPU
    property int gpuUsage: 0
    property int gpuTemp: 0
    property bool isNvidia: true
    property bool showGpuTemp: false

    // Memory
    property bool showMemPercent: true
    property int memUsagePercent: 0
    property string memText: "0%"

    // Disk
    property bool showDiskPercent: true
    property var disks: []
    property int currentDiskIdx: 0
    property string diskUsage: "0%"
    property string diskLabel: "/"

    // Audio / Wifi
    property int volumeLevel: 0
    property bool isMuted: false
    property int micLevel: 0
    property bool isMicMuted: false
    property string kernelVersion: "..."
    property string wifiSSID: "Offline"
    property int wifiStrength: 0

    // Command runner
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
        command: ["sh", "-c", "head -1 /proc/stat; cat /sys/class/thermal/thermal_zone*/temp | head -n 1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                if (data.startsWith("cpu")) {
                    var parts = data.trim().split(/\s+/)
                    var total = parts.slice(1, 8).reduce((a, b) => parseInt(a) + parseInt(b), 0)
                    var idle = parseInt(parts[4]) + parseInt(parts[5])
                    if (root.lastCpuTotal > 0) {
                        var totalDiff = total - root.lastCpuTotal
                        var idleDiff = idle - root.lastCpuIdle
                        if (totalDiff > 0) cpuUsage = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                    }
                    root.lastCpuTotal = total
                    root.lastCpuIdle = idle
                } else {
                    let tempVal = parseInt(data.trim())
                    if (!isNaN(tempVal)) root.cpuTemp = Math.round(tempVal / 1000)
                }
            }
        }
    }

    Process {
        id: gpuProc
        command: root.isNvidia
            ? ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits"]
            : ["sh", "-c", "echo \"$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0),$(cat /sys/class/thermal/thermal_zone1/temp 2>/dev/null | awk '{print int($1/1000)}' || echo 0)\""]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                let parts = data.split(",")
                if (parts.length >= 2) {
                    root.gpuUsage = parseInt(parts[0].trim()) || 0
                    root.gpuTemp = parseInt(parts[1].trim()) || 0
                } else if (parts.length === 1) {
                    root.gpuUsage = parseInt(parts[0].trim()) || 0
                }
            }
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free -m | grep Mem | awk '{print $3, $2}'"]
        stdout: SplitParser {
            onRead: d => {
                if(!d) return
                let parts = d.trim().split(" ")
                if (parts.length < 2) return
                let usedMb = parseInt(parts[0])
                let totalMb = parseInt(parts[1])
                root.memUsagePercent = Math.round((usedMb / totalMb) * 100)
                root.memText = root.showMemPercent ? root.memUsagePercent + "%" : (usedMb/1024).toFixed(1) + "G/" + (totalMb/1024).toFixed(1) + "G"
            }
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -h --output=pcent,used,size,target | grep -E '/$|/home|/mnt|/run/media|/media'"]
        property string outputBuffer: ""
        stdout: SplitParser { onRead: data => { if (data) diskProc.outputBuffer += data + "\n" } }
        onExited: {
            if (!diskProc.outputBuffer) return
            let lines = diskProc.outputBuffer.trim().split("\n")
            let parsedDisks = []
            lines.forEach(line => {
                let parts = line.trim().split(/\s+/)
                if (parts.length >= 4) {
                    let label = parts[3] === "/" ? "/" : parts[3].split('/').pop()
                    parsedDisks.push({ pcent: parts[0], absolute: parts[1] + "/" + parts[2], path: label })
                }
            })
            root.disks = parsedDisks
            if (root.currentDiskIdx >= root.disks.length) root.currentDiskIdx = 0
            root.updateDiskText()
            diskProc.outputBuffer = ""
        }
    }

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
                    let parts = data.trim().split(":")
                    wifiSSID = parts[1] || "Unknown"
                    wifiStrength = parseInt(parts[2]) || 0
                } else if (!wifiSSID || wifiSSID === "") {
                    wifiSSID = "Offline"
                    wifiStrength = 0
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
                if (match) { volumeLevel = Math.round(parseFloat(match[1]) * 100); isMuted = !!match[2] }
            }
        }
    }

    Process {
        id: micProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: SplitParser {
            onRead: data => {
                var match = data.match(/Volume:\s*([\d.]+)(\s*\[MUTED\])?/)
                if (match) { micLevel = Math.round(parseFloat(match[1]) * 100); isMicMuted = !!match[2] }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = false; cpuProc.running = true
            gpuProc.running = false; gpuProc.running = true
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
            color: root.cal0

            RowLayout {
                anchors.fill: parent
                spacing: 8
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                // --- 0. Profile Pill (Rofi Launcher) ---
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 26
                    color: root.cal2
                    radius: 13

                    Item {
                        width: 22
                        height: 22
                        anchors.centerIn: parent
                        Image {
                            id: profileIcon
                            anchors.fill: parent
                            source: "icon.png"
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }
                        Rectangle {
                            id: mask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                        }
                        OpacityMask {
                            anchors.fill: parent
                            source: profileIcon
                            maskSource: mask
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) shellCmd.command = ["rofi", "-show", "drun"]
                            else shellCmd.command = ["sh", "-c", "rofi_power"]
                            shellCmd.running = false
                            shellCmd.running = true
                        }
                    }
                }

                // --- 1. Workspaces (Animated) ---
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: (26 * 9) + 24
                    color: root.cal2
                    radius: 13
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: 9
                            Rectangle {
                                width: 24
                                height: 26
                                color: "transparent"
                                property var workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
                                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                                property bool hasWindows: workspace !== null

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.isActive ? "" : (parent.hasWindows ? "" : "")
                                    color: parent.isActive ? root.cal8 : (parent.hasWindows ? root.cal9 : root.cal3)
                                    font.pixelSize: parent.isActive ? root.fontSize + 2 : root.fontSize
                                    font.family: root.fontFamily

                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                                MouseArea { anchors.fill: parent; onClicked: { Hyprland.dispatch("workspace " + (index + 1)) } }
                            }
                        }
                    }
                }

                // --- 2. Layout Pill ---
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: layoutText.implicitWidth + 24
                    color: root.cal2
                    radius: 13
                    Text {
                        id: layoutText
                        anchors.centerIn: parent
                        text: root.currentLayout
                        color: root.cal7
                        font.pixelSize: root.fontSize - 2
                        font.family: root.fontFamily
                        font.bold: true
                    }
                }

                // --- 3. Window Title ---
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.fillWidth: true
                    Layout.minimumWidth: 100
                    color: root.cal2
                    radius: 13
                    clip: true
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        spacing: 10
                        Text {
                            text: root.activeWindow === "Desktop" ? "󰇄" : "󱂬"
                            color: root.cal10
                            font.pixelSize: root.fontSize + 2
                            font.family: root.fontFamily
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.activeWindow
                            color: root.cal6
                            font.pixelSize: root.fontSize
                            font.family: root.fontFamily
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // --- 4. Stats Pill ---
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: statsRow.implicitWidth + 30
                    color: root.cal2
                    radius: 13

                    RowLayout {
                        id: statsRow
                        anchors.centerIn: parent
                        spacing: 12

                        // --- KERNEL ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: kernelRow.width
                            Row {
                                id: kernelRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered

                                Text {
                                    text: "󰌽"
                                    color: root.cal9
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    width: parent.expanded ? kernelTxt.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text {
                                        id: kernelTxt
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.kernelVersion
                                        color: root.cal9
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.MiddleButton
                                hoverEnabled: true
                                onEntered: kernelRow.hovered = true
                                onExited: kernelRow.hovered = false
                                onClicked: (m) => { if(m.button === Qt.MiddleButton) kernelRow.pinned = !kernelRow.pinned }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // --- CPU ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: cpuRow.width
                            Row {
                                id: cpuRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered

                                Text {
                                    text: ""
                                    color: root.cal11
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    width: parent.expanded ? cpuTxt.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text {
                                        id: cpuTxt
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.showCpuTemp ? root.cpuTemp + "°C" : root.cpuUsage + "%"
                                        color: root.cal11
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                hoverEnabled: true
                                onEntered: cpuRow.hovered = true
                                onExited: cpuRow.hovered = false
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) cpuRow.pinned = !cpuRow.pinned
                                    else if (m.button === Qt.LeftButton) root.showCpuTemp = !root.showCpuTemp
                                }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // --- GPU (REDESIGNED) ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: gpuRow.width
                            Row {
                                id: gpuRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered

                                Text {
                                    text: "󰢮"
                                    color: root.isNvidia ? root.cal13 : root.cal7
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    // Calculate width based on the entire content row (Badge + Text)
                                    width: parent.expanded ? gpuContent.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                                    Row {
                                        id: gpuContent
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }

                                        // The BADGE (Different for NV / IN)
                                        Rectangle {
                                            width: 24
                                            height: 16
                                            radius: 4
                                            color: root.isNvidia ? root.cal13 : root.cal7
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.isNvidia ? "NV" : "IN"
                                                color: root.cal0
                                                font.pixelSize: 10
                                                font.family: root.fontFamily
                                                font.bold: true
                                            }
                                        }

                                        // The DATA
                                        Text {
                                            text: root.showGpuTemp ? root.gpuTemp + "°C" : root.gpuUsage + "%"
                                            color: root.isNvidia ? root.cal13 : root.cal7
                                            font.pixelSize: root.fontSize
                                            font.family: root.fontFamily
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                hoverEnabled: true
                                onEntered: gpuRow.hovered = true
                                onExited: gpuRow.hovered = false
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) gpuRow.pinned = !gpuRow.pinned
                                    else if (m.button === Qt.LeftButton) { root.isNvidia = !root.isNvidia; gpuProc.running = false; gpuProc.running = true }
                                    else if (m.button === Qt.RightButton) { root.showGpuTemp = !root.showGpuTemp }
                                }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // --- RAM ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: memRow.width
                            Row {
                                id: memRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered

                                Text {
                                    text: ""
                                    color: root.cal13
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    width: parent.expanded ? memTxt.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text {
                                        id: memTxt
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.memText
                                        color: root.cal13
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                hoverEnabled: true
                                onEntered: memRow.hovered = true
                                onExited: memRow.hovered = false
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) memRow.pinned = !memRow.pinned
                                    else if (m.button === Qt.LeftButton) { root.showMemPercent = !root.showMemPercent; memProc.running = false; memProc.running = true }
                                }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // --- DISK ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: diskRow.width
                            Row {
                                id: diskRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered

                                Text {
                                    text: "󰋊"
                                    color: root.cal7
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    width: parent.expanded ? diskTxt.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text {
                                        id: diskTxt
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.diskLabel + ": " + root.diskUsage
                                        color: root.cal7
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                hoverEnabled: true
                                onEntered: diskRow.hovered = true
                                onExited: diskRow.hovered = false
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) diskRow.pinned = !diskRow.pinned
                                    else if (m.button === Qt.LeftButton && root.disks.length > 0) { root.currentDiskIdx = (root.currentDiskIdx + 1) % root.disks.length; root.updateDiskText(); }
                                    else if (m.button === Qt.RightButton) { root.showDiskPercent = !root.showDiskPercent; root.updateDiskText(); }
                                }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // --- WIFI ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: wifiRow.width
                            Row {
                                id: wifiRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered
                                property string icon: root.wifiSSID === "Offline" ? "󰤮" : (root.wifiStrength > 75 ? "󰤨" : (root.wifiStrength > 50 ? "󰤥" : "󰤢"))

                                Text {
                                    text: parent.icon
                                    color: root.wifiSSID === "Offline" ? root.cal11 : root.cal10
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    width: parent.expanded ? wifiTxt.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text {
                                        id: wifiTxt
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (root.wifiSSID === "Offline" ? "Searching..." : root.wifiSSID) + " (" + root.wifiStrength + "%)"
                                        color: root.wifiSSID === "Offline" ? root.cal11 : root.cal10
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                hoverEnabled: true
                                onEntered: wifiRow.hovered = true
                                onExited: wifiRow.hovered = false
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) wifiRow.pinned = !wifiRow.pinned
                                    else if (m.button === Qt.LeftButton) { shellCmd.command = ["sh", "-c", "rofi_wifi"]; shellCmd.running = false; shellCmd.running = true }
                                    else if (m.button === Qt.RightButton) { shellCmd.command = ["nm-connection-editor"]; shellCmd.running = false; shellCmd.running = true }
                                }
                            }
                        }

                        Rectangle { width: 2; height: 14; color: root.cal2; radius: 1 }

                        // --- MIC ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: micRow.width
                            Row {
                                id: micRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered

                                Text {
                                    text: root.isMicMuted ? "󰍭" : "󰍬"
                                    color: root.isMicMuted ? root.cal3 : root.cal8
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    width: parent.expanded ? micTxt.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text {
                                        id: micTxt
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.micLevel + "%"
                                        color: root.isMicMuted ? root.cal3 : root.cal8
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                hoverEnabled: true
                                onEntered: micRow.hovered = true
                                onExited: micRow.hovered = false
                                onWheel: (w) => {
                                    if (w.angleDelta.y > 0) {
                                        if (root.micLevel < 100) {
                                            root.micLevel = Math.min(100, root.micLevel + 5);
                                            shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", "5%+"];
                                            shellCmd.running = false; shellCmd.running = true;
                                        }
                                    } else {
                                        root.micLevel = Math.max(0, root.micLevel - 5);
                                        shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", "5%-"];
                                        shellCmd.running = false; shellCmd.running = true;
                                    }
                                }
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) micRow.pinned = !micRow.pinned
                                    else if (m.button === Qt.LeftButton) { shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]; shellCmd.running = false; shellCmd.running = true }
                                    else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol"]; shellCmd.running = false; shellCmd.running = true }
                                }
                            }
                        }

                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // --- AUDIO ---
                        Item {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: audioRow.width
                            Row {
                                id: audioRow
                                spacing: 0
                                property bool pinned: false
                                property bool hovered: false
                                readonly property bool expanded: pinned || hovered

                                Text {
                                    text: root.isMuted ? "󰝟" : ""
                                    color: root.isMuted ? root.cal3 : root.cal14
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    height: 20
                                    width: parent.expanded ? audioTxt.implicitWidth + 8 : 0
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text {
                                        id: audioTxt
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.volumeLevel + "%"
                                        color: root.isMuted ? root.cal3 : root.cal14
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        opacity: parent.width > 5 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                hoverEnabled: true
                                onEntered: audioRow.hovered = true
                                onExited: audioRow.hovered = false
                                onWheel: (w) => {
                                    if (w.angleDelta.y > 0) {
                                        if (root.volumeLevel < 100) {
                                            root.volumeLevel = Math.min(100, root.volumeLevel + 5);
                                            shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"];
                                            shellCmd.running = false; shellCmd.running = true;
                                        }
                                    } else {
                                        root.volumeLevel = Math.max(0, root.volumeLevel - 5);
                                        shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%-"];
                                        shellCmd.running = false; shellCmd.running = true;
                                    }
                                }
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) audioRow.pinned = !audioRow.pinned
                                    else if (m.button === Qt.LeftButton) { shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; shellCmd.running = false; shellCmd.running = true }
                                    else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol"]; shellCmd.running = false; shellCmd.running = true }
                                }
                            }
                        }
                    }
                }

                // --- 5. Clock ---
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: clockText.implicitWidth + 30
                    color: root.cal2
                    radius: 13
                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        property var dateTime: new Date()
                        text: Qt.formatDateTime(dateTime, "󰥔  hh:mm AP |   dddd MMMM dd yyyy")
                        color: root.cal6
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                        font.bold: true
                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: parent.dateTime = new Date()
                        }
                    }
                }
            }
        }
    }
}
