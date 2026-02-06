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
    readonly property color cal0:  "#0f0f0f" // Background
    readonly property color cal1:  "#1a1a1a" // Pills
    readonly property color cal2:  "#2d2d2d" // Pill BG
    readonly property color cal3:  "#4c1111" // Separators
    readonly property color cal6:  "#f9e5c7" // Main Text
    readonly property color cal7:  "#3ec1d3" // Teal (Storage/Memory)
    readonly property color cal8:  "#ff4646" // Red
    readonly property color cal9:  "#b45ef7" // Purple (System Core)
    readonly property color cal10: "#df9d1b" // Gold (Power)
    readonly property color cal11: "#ff003c" // Alert Red
    readonly property color cal13: "#73f973" // Green (Network)
    readonly property color cal14: "#ffa500" // Orange (Audio)
    readonly property color cal15: "#e0e0e0" // Silver

    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13

    // --- Window Data ---
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

    // --- System Data Properties ---

    // Kernel / CPU / GPU
    property string kernelIcon: ""; property string kernelVersion: "..."
    property string cpuIcon: "";    property string cpuText: "0%"
    property string gpuIcon: "󰢮";    property string gpuText: "0%"

    // Memory
    property string memIcon: "";    property string memText: "0%"

    // Disk
    property string diskIcon: "󰋊";   property string diskText: "0%"

    // Brightness
    property string brightIcon: "󰃠"; property string brightText: "100%"; property bool showBright: false

    // Battery
    property string batIcon: "󰢜";    property string batText: "100%"; property bool showBat: false

    // Network (Ethernet, Wifi, Tailscale)
    property string ethIcon: "󰲜";    property string ethText: "Disconnected"; property bool showEth: false
    property string wifiIcon: "󰤮";   property string wifiText: "Offline"; property bool showWifi: true
    property string tailIcon: "󰈂";   property string tailText: "Not connected"; property bool showTail: false

    // Audio / Mic
    property string volIcon: "󰕾";    property string volText: "0%"
    property string micIcon: "";    property string micText: "0%"

    // --- Logic & Process Control ---

    Process { id: shellCmd }

    // Helper function to split "ICON TEXT" output
    function parseSysstats(data, iconProp, textProp) {
        if (!data) return;
        let parts = data.trim().split(/\s+/);
        if (parts.length >= 1) root[iconProp] = parts[0];
        if (parts.length >= 2) root[textProp] = parts.slice(1).join(" ");
    }

    Process {
        id: kernelProc; command: ["sysstats", "kernel"];
        stdout: SplitParser { onRead: data => root.parseSysstats(data, "kernelIcon", "kernelVersion") }
    }

    Process {
        id: cpuProc; command: ["sysstats", "cpu"]
        stdout: SplitParser { onRead: data => root.parseSysstats(data, "cpuIcon", "cpuText") }
    }

    Process {
        id: gpuProc; command: ["sysstats", "gpu"]
        stdout: SplitParser { onRead: data => root.parseSysstats(data, "gpuIcon", "gpuText") }
    }

    Process {
        id: memProc; command: ["sysstats", "mem"]
        stdout: SplitParser { onRead: data => root.parseSysstats(data, "memIcon", "memText") }
    }

    Process {
        id: diskProc; command: ["sysstats", "disk"]
        stdout: SplitParser { onRead: data => root.parseSysstats(data, "diskIcon", "diskText") }
    }

    Process {
        id: brightProc; command: ["sysstats", "brightness"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || data.trim() === "" || data.includes("N/A")) {
                    root.showBright = false; return
                }
                root.showBright = true;
                root.parseSysstats(data, "brightIcon", "brightText")
            }
        }
    }

    Process {
        id: batProc; command: ["sysstats", "battery"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || data.trim() === "") { root.showBat = false; return }
                root.showBat = true;
                root.parseSysstats(data, "batIcon", "batText")
            }
        }
    }

    // --- Network Processes ---
    Process {
        id: ethProc
        command: ["sysstats", "ethernet"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                root.parseSysstats(data, "ethIcon", "ethText")
                root.showEth = data.includes("Connected")
            }
        }
    }

    Process {
        id: wifiProc; command: ["sysstats", "wifi"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                root.parseSysstats(data, "wifiIcon", "wifiText")
                let isWifiConnected = !data.includes("Offline") && !data.includes("No tool") && !data.includes("Disconnected");
                root.showWifi = isWifiConnected || !root.showEth;
            }
        }
    }

    Process {
        id: tailProc
        command: ["sysstats", "tail"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return;
                root.parseSysstats(data, "tailIcon", "tailText")
                root.showTail = data.includes("Connected") && !data.includes("Not connected")
            }
        }
    }

    Process {
        id: volProc; command: ["sysstats", "volume"]
        stdout: SplitParser { onRead: data => root.parseSysstats(data, "volIcon", "volText") }
    }

    Process {
        id: micProc; command: ["sysstats", "microphone"]
        stdout: SplitParser { onRead: data => root.parseSysstats(data, "micIcon", "micText") }
    }

    // Periodic Background Refresh
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuProc.running = false;    cpuProc.running = true
            gpuProc.running = false;    gpuProc.running = true
            kernelProc.running = false; kernelProc.running = true
            memProc.running = false;    memProc.running = true
            diskProc.running = false;   diskProc.running = true
            brightProc.running = false; brightProc.running = true
            wifiProc.running = false;   wifiProc.running = true
            ethProc.running = false;    ethProc.running = true
            tailProc.running = false;   tailProc.running = true
            batProc.running = false;    batProc.running = true
            volProc.running = false;    volProc.running = true
            micProc.running = false;    micProc.running = true
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
                anchors.fill: parent; spacing: 8; anchors.leftMargin: 12; anchors.rightMargin: 12

                // 0. Profile
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 26; color: root.cal2; radius: 13
                    Item {
                        width: 22; height: 22; anchors.centerIn: parent
                        Image { id: profileIcon; anchors.fill: parent; source: "icon.png"; fillMode: Image.PreserveAspectCrop; visible: false }
                        Rectangle { id: mask; anchors.fill: parent; radius: width / 2; visible: false }
                        OpacityMask { anchors.fill: parent; source: profileIcon; maskSource: mask }
                    }
                    MouseArea {
                        anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (m) => {
                            if (m.button === Qt.LeftButton) shellCmd.command = ["rofi", "-show", "drun"]
                            else shellCmd.command = ["sh", "-c", "rofi_power"]
                            shellCmd.running = false; shellCmd.running = true
                        }
                    }
                }

                // 1. Workspaces
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: (26 * 9) + 24; color: root.cal2; radius: 13
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

                // 2. Layout
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: layoutText.implicitWidth + 24; color: root.cal2; radius: 13
                    Text { id: layoutText; anchors.centerIn: parent; text: root.currentLayout; color: root.cal7; font.pixelSize: root.fontSize - 2; font.family: root.fontFamily; font.bold: true }
                }

                // 3. Window
                Rectangle {
                    Layout.preferredHeight: 26; Layout.fillWidth: true; Layout.minimumWidth: 100; color: root.cal2; radius: 13; clip: true
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 10
                        Text { text: root.activeWindow === "Desktop" ? "󰇄" : "󱂬"; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily }
                        Text { Layout.fillWidth: true; text: root.activeWindow; color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                // 4. Stats
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: statsRow.implicitWidth + 30; color: root.cal2; radius: 13
                    RowLayout {
                        id: statsRow; anchors.centerIn: parent; spacing: 12

                        // === SYSTEM CORE GROUP (Purple) ===
                        // Kernel
                        Item {
                            Layout.preferredHeight: 20; Layout.preferredWidth: kernelRow.width
                            Row {
                                id: kernelRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.kernelIcon; color: root.cal9; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? kernelTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: kernelTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.kernelVersion; color: root.cal9; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: kernelRow.hovered = true; onExited: kernelRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) kernelRow.pinned = !kernelRow.pinned } }
                        }

                        // CPU
                        Item {
                            Layout.preferredHeight: 20; Layout.preferredWidth: cpuRow.width
                            Row {
                                id: cpuRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.cpuIcon; color: root.cal9; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? cpuTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: cpuTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.cpuText; color: root.cal9; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: cpuRow.hovered = true; onExited: cpuRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) cpuRow.pinned = !cpuRow.pinned; } }
                        }

                        // GPU
                        Item {
                            Layout.preferredHeight: 20; Layout.preferredWidth: gpuRow.width
                            Row {
                                id: gpuRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.gpuIcon; color: root.cal9; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? gpuTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: gpuTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.gpuText; color: root.cal9; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: gpuRow.hovered = true; onExited: gpuRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) gpuRow.pinned = !gpuRow.pinned; } }
                        }

                        // --- Separator: Core -> Memory ---
                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // === MEMORY & STORAGE GROUP (Teal) ===
                        // RAM
                        Item {
                            Layout.preferredHeight: 20; Layout.preferredWidth: memRow.width
                            Row {
                                id: memRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.memIcon; color: root.cal7; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? memTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: memTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.memText; color: root.cal7; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton; hoverEnabled: true;
                                onEntered: memRow.hovered = true; onExited: memRow.hovered = false;
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) memRow.pinned = !memRow.pinned;
                                    else if (m.button === Qt.LeftButton) { memProc.running = false; memProc.running = true }
                                }
                            }
                        }

                        // Disk
                        Item {
                            Layout.preferredHeight: 20; Layout.preferredWidth: diskRow.width
                            Row {
                                id: diskRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.diskIcon; color: root.cal7; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? diskTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: diskTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.diskText; color: root.cal7; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: diskRow.hovered = true; onExited: diskRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) diskRow.pinned = !diskRow.pinned; } }
                        }

                        // --- Separator: Storage -> Power ---
                        Rectangle { width: 1; height: 12; color: root.cal3; visible: root.showBright || root.showBat }

                        // === POWER GROUP (Gold) ===
                        // Brightness
                        Item {
                            visible: root.showBright
                            Layout.preferredHeight: 20; Layout.preferredWidth: brightRow.width
                            Row {
                                id: brightRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.brightIcon; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? brightTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: brightTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.brightText; color: root.cal10; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: brightRow.hovered = true; onExited: brightRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) brightRow.pinned = !brightRow.pinned } }
                        }

                        // Battery
                        Rectangle { width: 1; height: 12; color: root.cal3; visible: root.showBat && !root.showBright }
                        Item {
                            visible: root.showBat; Layout.preferredHeight: 20; Layout.preferredWidth: batRow.width
                            Row {
                                id: batRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.batIcon; color: root.cal10; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? batTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: batTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.batText; color: root.cal10; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true; onEntered: batRow.hovered = true; onExited: batRow.hovered = false; onClicked: (m) => { if(m.button === Qt.MiddleButton) batRow.pinned = !batRow.pinned } }
                        }

                        // --- Separator: Power -> Network ---
                        Rectangle { width: 1; height: 12; color: root.cal3; visible: (root.showEth || root.showWifi || root.showTail) }

                        // === NETWORK GROUP (Green) ===
                        // Ethernet
                        Item {
                            visible: root.showEth
                            Layout.preferredHeight: 20; Layout.preferredWidth: ethRow.width
                            Row {
                                id: ethRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.ethIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? ethTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: ethTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.ethText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton | Qt.RightButton; hoverEnabled: true;
                                onEntered: ethRow.hovered = true; onExited: ethRow.hovered = false;
                                onClicked: (m) => { if(m.button === Qt.MiddleButton) ethRow.pinned = !ethRow.pinned; else if (m.button === Qt.RightButton) { shellCmd.command = ["nm-connection-editor"]; shellCmd.running = false; shellCmd.running = true } }
                            }
                        }

                        // WIFI
                        Item {
                            visible: root.showWifi
                            Layout.preferredHeight: 20; Layout.preferredWidth: wifiRow.width
                            Row {
                                id: wifiRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.wifiIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? wifiTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: wifiTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.wifiText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true
                                onEntered: wifiRow.hovered = true; onExited: wifiRow.hovered = false
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) wifiRow.pinned = !wifiRow.pinned;
                                    else if (m.button === Qt.LeftButton) { shellCmd.command = ["sh", "-c", "rofi_wifi"]; shellCmd.running = false; shellCmd.running = true }
                                    else if (m.button === Qt.RightButton) { shellCmd.command = ["nm-connection-editor"]; shellCmd.running = false; shellCmd.running = true }
                                }
                            }
                        }

                        // Tailscale
                        Item {
                            visible: root.showTail
                            Layout.preferredHeight: 20; Layout.preferredWidth: tailRow.width
                            Row {
                                id: tailRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.tailIcon; color: root.cal13; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? tailTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: tailTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.tailText; color: root.cal13; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.MiddleButton; hoverEnabled: true
                                onEntered: tailRow.hovered = true; onExited: tailRow.hovered = false
                                onClicked: (m) => { if(m.button === Qt.MiddleButton) tailRow.pinned = !tailRow.pinned }
                            }
                        }

                        // --- Separator: Network -> Audio ---
                        Rectangle { width: 1; height: 12; color: root.cal3 }

                        // === AUDIO GROUP (Orange) ===
                        // Microphone
                        Item {
                            Layout.preferredHeight: 20; Layout.preferredWidth: micRow.width
                            Row {
                                id: micRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.micIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? micTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: micTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.micText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true
                                onEntered: micRow.hovered = true; onExited: micRow.hovered = false
                                onWheel: (wheel) => {
                                    if(wheel.angleDelta.y > 0) shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", "5%+"];
                                    else shellCmd.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "5%-"];
                                    shellCmd.running = false; shellCmd.running = true; micProc.running = false; micProc.running = true
                                }
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) micRow.pinned = !micRow.pinned;
                                    else if (m.button === Qt.LeftButton) { shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]; shellCmd.running = false; shellCmd.running = true; micProc.running = false; micProc.running = true }
                                    else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol", "-t", "4"]; shellCmd.running = false; shellCmd.running = true }
                                }
                            }
                        }

                        // Volume
                        Item {
                            Layout.preferredHeight: 20; Layout.preferredWidth: volRow.width
                            Row {
                                id: volRow; spacing: 0; property bool pinned: false; property bool hovered: false; readonly property bool expanded: pinned || hovered
                                Text { text: root.volIcon; color: root.cal14; font.pixelSize: root.fontSize + 2; font.family: root.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                                Item { height: 20; width: parent.expanded ? volTxt.implicitWidth + 8 : 0; clip: true; anchors.verticalCenter: parent.verticalCenter; Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Text { id: volTxt; anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: root.volText; color: root.cal14; font.pixelSize: root.fontSize; font.family: root.fontFamily; opacity: parent.width > 5 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; hoverEnabled: true
                                onEntered: volRow.hovered = true; onExited: volRow.hovered = false
                                onWheel: (wheel) => {
                                    if(wheel.angleDelta.y > 0) shellCmd.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"];
                                    else shellCmd.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"];
                                    shellCmd.running = false; shellCmd.running = true; volProc.running = false; volProc.running = true
                                }
                                onClicked: (m) => {
                                    if(m.button === Qt.MiddleButton) volRow.pinned = !volRow.pinned;
                                    else if (m.button === Qt.LeftButton) { shellCmd.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; shellCmd.running = false; shellCmd.running = true; volProc.running = false; volProc.running = true }
                                    else if (m.button === Qt.RightButton) { shellCmd.command = ["pavucontrol", "-t", "3"]; shellCmd.running = false; shellCmd.running = true }
                                }
                            }
                        }

                    }
                }

                // 5. Clock
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: clockText.implicitWidth + 30; color: root.cal2; radius: 13
                    Text {
                        id: clockText; anchors.centerIn: parent; property var dateTime: new Date(); text: Qt.formatDateTime(dateTime, "󰥔  hh:mm AP |   dddd MMMM dd yyyy")
                        color: root.cal6; font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                        Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.dateTime = new Date() }
                    }
                }
            }
        }
    }
}
