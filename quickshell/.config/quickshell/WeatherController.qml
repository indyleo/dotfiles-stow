import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

Item {
    id: root

    property bool active: false

    // New expanded properties
    property string weatherIcon: "󰖐"
    property string temperature: "--"
    property string condition: "--"
    property string feelsLike: "--"
    property string humidity: "--"
    property string wind: "--"

    // Optional custom location (e.g. "Paris" or "New York"). Empty means
    // wttr.in's default IP-based auto-detection, which is the only option
    // the previous version supported.
    property string location: ""

    // Surfaced in the UI instead of leaving stale "--" placeholders forever
    // with no indication that the fetch or parse actually failed.
    property bool hasError: false
    property string errorMessage: ""

    // Font sourced from the central Theme singleton (Theme.qml)
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize

    Process {
        id: weatherProc
        // Replaced sysstats with curl fetching JSON.
        // --max-time avoids hanging forever if the network is down; -f
        // makes curl itself report failure on HTTP error responses instead
        // of happily returning an error page that JSON.parse would then
        // choke on with a confusing error.
        command: ["curl", "-s", "-f", "--max-time", "10",
            "wttr.in/" + encodeURIComponent(root.location) + "?format=j1"]
        stderr: StdioCollector {}
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") return // handled in onExited via exit code
                try {
                    var data = JSON.parse(text.trim())
                    var current = data.current_condition[0]

                    root.temperature = current.temp_C + "°C"
                    root.feelsLike = "Feels like " + current.FeelsLikeC + "°C"
                    root.condition = current.weatherDesc[0].value
                    root.humidity = "Humidity: " + current.humidity + "%"
                    root.wind = "Wind: " + current.windspeedKmph + " km/h"

                    // Simple matching to map conditions to icons
                    var condLow = root.condition.toLowerCase()
                    if (condLow.includes("sun") || condLow.includes("clear")) root.weatherIcon = "󰖙"
                    else if (condLow.includes("rain") || condLow.includes("drizzle")) root.weatherIcon = "󰖗"
                    else if (condLow.includes("cloud") || condLow.includes("overcast")) root.weatherIcon = "󰖐"
                    else if (condLow.includes("snow")) root.weatherIcon = "󰖘"
                    else if (condLow.includes("thunder") || condLow.includes("storm")) root.weatherIcon = "󰖓"
                    else root.weatherIcon = "󰖐"

                    root.hasError = false
                    root.errorMessage = ""
                } catch(e) {
                    console.log("Weather parse error: " + e)
                    root.hasError = true
                    root.errorMessage = "Couldn't read weather data"
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[WeatherController] curl failed with exit code", code, weatherProc.stderr.text)
                root.hasError = true
                root.errorMessage = code === 28 ? "Weather request timed out" : "Couldn't reach weather service"
            }
        }
    }

    Timer {
        interval: 600000 // Updates every 10 minutes
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            weatherProc.running = false
            weatherProc.running = true
        }
    }

    PanelWindow {
        id: weatherWindow
        screen: Quickshell.screens[0]
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; bottom: true; left: true; right: true }

        // Increased height to accommodate the new layout
        Rectangle {
            width: 300
            height: 360
            anchors.centerIn: parent
            radius: 16
            color: "#282828"
            border.width: 2
            border.color: "#83a598"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: root.weatherIcon
                    color: "#83a598"
                    font.family: root.fontFamily
                    font.pixelSize: 64
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: root.temperature
                    color: "#ebdbb2"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize + 12
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: root.condition
                    color: "#fabd2f"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    visible: root.hasError
                    text: root.errorMessage
                    color: "#fb4934"
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize - 1
                    Layout.alignment: Qt.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.maximumWidth: 240
                    horizontalAlignment: Text.AlignHCenter
                }

                // Grid layout for secondary details
                GridLayout {
                    columns: 1
                    rowSpacing: 6
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12

                    Text {
                        text: root.feelsLike
                        color: "#a89984"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 1
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.humidity
                        color: "#a89984"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 1
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.wind
                        color: "#a89984"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize - 1
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Rectangle {
                    id: weatherCloseBtn
                    width: 100
                    height: 30
                    radius: 15
                    color: "#504945"
                    border.width: 2
                    border.color: "#7c6f64"
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        color: "#ebdbb2"
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: {
                            weatherCloseBtn.color = "#7c6f64"
                            weatherCloseBtn.border.color = "#ebdbb2"
                        }
                        onExited: {
                            weatherCloseBtn.color = "#504945"
                            weatherCloseBtn.border.color = "#7c6f64"
                        }
                        onClicked: root.active = false
                    }
                }
            }
        }
    }
}