import QtQuick
import QtQuick.Layouts

Rectangle {
    id: btnRoot

    property string icon: ""
    property string label: ""
    property color bgColor: "#504945"
    property color hoverColor: "#7c6f64"
    property color iconColor: "#fe8019"
    property color textColor: "#ebdbb2"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13

    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: 64
    radius: 12
    color: bgColor

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: btnRoot.icon
            color: btnRoot.iconColor
            font.family: btnRoot.fontFamily
            font.pixelSize: btnRoot.fontSize + 8
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: btnRoot.label
            color: btnRoot.textColor
            font.family: btnRoot.fontFamily
            font.pixelSize: btnRoot.fontSize - 2
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: btnRoot.color = btnRoot.hoverColor
        onExited: btnRoot.color = btnRoot.bgColor
        onClicked: btnRoot.clicked()
    }
}
