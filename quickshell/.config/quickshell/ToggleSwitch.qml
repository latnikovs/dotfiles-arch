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
        color: toggle.checked ? "#88c0d0" : "#4c566a"

        Rectangle {
            x: toggle.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 6
            height: width
            radius: width / 2
            color: toggle.checked ? "#2e3440" : "#d8dee9"

            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
    }
}
