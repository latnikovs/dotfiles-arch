// A bar dropdown: a card centered under its button (slid back on screen at the edges).
// Esc or a click anywhere else closes it. Content goes in as children, laid out at panelWidth.
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: dropdown

    required property var bar
    required property Item button
    property bool open: false
    property int panelWidth: 340
    readonly property int padding: 16
    default property alias content: body.data

    // Keys the bar hands over while this is open; true when used
    function handleKey(event): bool {
        return false;
    }

    visible: open
    color: "transparent"
    implicitWidth: panelWidth
    implicitHeight: body.childrenRect.height + 2 * padding + 6

    anchor {
        id: dropdownAnchor
        window: dropdown.bar
        adjustment: PopupAdjustment.Slide
        rect.width: 1
        rect.height: 1
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        onAnchoring: {
            const b = dropdown.button;
            const p = dropdown.bar.contentItem.mapFromItem(b, b.width / 2 - dropdown.implicitWidth / 2, 0);
            dropdownAnchor.rect.x = Math.round(p.x);
            dropdownAnchor.rect.y = dropdown.bar.height;
        }
    }

    Rectangle {
        anchors {
            fill: parent
            topMargin: 6
        }
        color: dropdown.bar.bg
        border.color: dropdown.bar.muted
        border.width: 1
        radius: 10
        focus: true
        Keys.onPressed: event => dropdown.bar.panelKey(event)

        Item {
            id: body
            anchors {
                fill: parent
                margins: dropdown.padding
            }
        }
    }

    // The bar is included so its button can toggle the dropdown
    HyprlandFocusGrab {
        windows: [dropdown, dropdown.bar]
        active: dropdown.backingWindowVisible
        onCleared: dropdown.open = false
    }
}
