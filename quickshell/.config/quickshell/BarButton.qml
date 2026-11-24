// A clickable widget on the bar: a soft highlight and a small lift on hover, a dip while
// pressed (as in Omarchy), and a pop or a wiggle when what it shows grows (`watch`)
import QtQuick

MouseArea {
    id: button

    // Set to a number that grows when there's something new (a count, an unread flag):
    // each increase plays `attention`. Decreases are quiet.
    property int watch: 0
    property string attention: "pop" // or "wiggle"
    // How much wider than the button its hover highlight is (0 for tightly packed ones)
    property int hoverPad: 10

    property int lastWatch: 0
    property real pop: 1
    property real tilt: 0

    hoverEnabled: true
    scale: pressed ? 0.85 : containsMouse ? 1.06 : 1
    transform: [
        Scale {
            origin.x: button.width / 2
            origin.y: button.height / 2
            xScale: button.pop
            yScale: button.pop
        },
        Rotation {
            origin.x: button.width / 2
            origin.y: button.height / 2
            angle: button.tilt
        }
    ]

    Component.onCompleted: lastWatch = watch
    onWatchChanged: {
        if (watch > lastWatch)
            bump();
        lastWatch = watch;
    }

    function bump() {
        if (attention === "wiggle")
            wiggleAnim.restart();
        else
            popAnim.restart();
    }

    Behavior on scale {
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutBack
        }
    }

    // Behind the content: the hover highlight, a little wider and taller than what it holds
    Rectangle {
        z: -1
        anchors.centerIn: parent
        width: parent.width + button.hoverPad
        height: Math.min(20, parent.height + 8)
        radius: height / 2
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, Theme.dark ? 0.12 : 0.16)
        opacity: button.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation {
            target: button
            property: "pop"
            to: 1.4
            duration: 120
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: button
            property: "pop"
            to: 1
            duration: 420
            easing.type: Easing.OutElastic
            easing.amplitude: 1.2
            easing.period: 0.35
        }
    }

    SequentialAnimation {
        id: wiggleAnim
        NumberAnimation { target: button; property: "tilt"; to: 18; duration: 70 }
        NumberAnimation { target: button; property: "tilt"; to: -15; duration: 110 }
        NumberAnimation { target: button; property: "tilt"; to: 10; duration: 100 }
        NumberAnimation { target: button; property: "tilt"; to: -5; duration: 90 }
        NumberAnimation { target: button; property: "tilt"; to: 0; duration: 80 }
    }
}
