import QtQuick
import QtQuick.Layouts

Rectangle {
    id: btnRoot

    property string icon: ""
    property string label: ""
    // Defaults sourced from Theme.qml; still overridable per-instance
    property color bgColor: Theme.buttonBg
    property color hoverColor: Theme.buttonHoverBg
    property color iconColor: Theme.buttonIcon
    property color textColor: Theme.buttonText
    property string fontFamily: Theme.fontFamily
    property int fontSize: Theme.fontSize

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
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: btnRoot.label
            color: btnRoot.textColor
            font.family: btnRoot.fontFamily
            font.pixelSize: btnRoot.fontSize - 2
            Layout.alignment: Qt.AlignHCenter
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