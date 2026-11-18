// A bar dropdown: a card centered under its button (slid back on screen at the edges),
// sliding out from under the bar (PanelCard.qml).
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

    visible: card.shown
    color: "transparent"
    implicitWidth: panelWidth
    implicitHeight: body.childrenRect.height + 2 * padding + 6

    anchor {
        window: dropdown.bar
        adjustment: PopupAdjustment.Slide
        rect.width: 1
        rect.height: 1
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        onAnchoring: {
            const b = dropdown.button;
            const p = dropdown.bar.contentItem.mapFromItem(b, b.width / 2 - dropdown.implicitWidth / 2, 0);
            dropdown.anchor.rect.x = Math.round(p.x);
            dropdown.anchor.rect.y = dropdown.bar.height;
        }
    }

    PanelCard {
        id: card
        bar: dropdown.bar
        open: dropdown.open

        Item {
            id: body
            anchors {
                fill: parent
                margins: dropdown.padding
            }
        }
    }

    // The bar is included so its button can toggle the dropdown
    // Held until the card has slid away: ending it while the popup is still up hands focus back to
    // the last window, and a hidden scratchpad console then pops up
    HyprlandFocusGrab {
        windows: [dropdown, dropdown.bar]
        active: dropdown.backingWindowVisible
        onCleared: dropdown.open = false
    }
}
