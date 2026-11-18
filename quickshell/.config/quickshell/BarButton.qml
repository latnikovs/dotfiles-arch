// A clickable widget on the bar: it dips a little while pressed, so a click is felt (as in Omarchy)
import QtQuick

MouseArea {
    scale: pressed ? 0.85 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutQuad
        }
    }
}
