// The card of a bar popup (dropdowns, calendar, weather, layouts, notification history).
// It slides down out from under the bar when it opens and back up when it closes, as Omarchy's
// panels do. The popup window stays mapped while the card slides away: bind its `visible` to `shown`.
import QtQuick

Item {
    id: card

    required property var bar
    required property bool open
    default property alias content: frame.data
    // Keep the window up until the card has slid away
    readonly property bool shown: open || progress > 0
    // 0 hidden under the bar, 1 in place
    property real progress: open ? 1 : 0

    // Gap between the bar and the card: Hyprland's gaps_out (hyprland.lua), so it lines up with the windows
    readonly property int gap: 3

    Behavior on progress {
        NumberAnimation {
            duration: card.open ? 180 : 130
            easing.type: card.open ? Easing.OutCubic : Easing.InCubic
        }
    }

    anchors.fill: parent
    // The window's top edge is the bar's bottom edge: the card appears from there
    clip: true

    Rectangle {
        id: frame
        width: parent.width
        height: parent.height - card.gap
        y: card.gap - (1 - card.progress) * parent.height
        opacity: 0.3 + 0.7 * card.progress
        color: card.bar.bg
        border.color: card.bar.muted
        border.width: 1
        radius: 5
        focus: true
        Keys.onPressed: event => card.bar.panelKey(event)
    }
}
