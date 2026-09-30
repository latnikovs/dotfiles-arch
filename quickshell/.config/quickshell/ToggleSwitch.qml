// On/off switch for the dropdown headers (Wi-Fi, Bluetooth)
import QtQuick

MouseArea {
    id: toggle

    property bool checked: false
    signal toggled

    implicitWidth: 32
    implicitHeight: 18
    cursorShape: Qt.PointingHandCursor
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? Theme.accent : Theme.muted

        Rectangle {
            x: toggle.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 6
            height: width
            radius: width / 2
            color: toggle.checked ? Theme.bg : Theme.fg

            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
    }
}
