// A page of the control center (ControlCenter.qml): network, Bluetooth, Tailscale, Syncthing,
// display, reminders. The host sets `open` while the page shows and its width; the page asks to
// be closed with close(). Content goes in as children, laid out at the page's width.
import QtQuick

Item {
    id: page

    required property var bar
    property bool open: false

    signal closeRequested

    function close(): void {
        closeRequested();
    }

    // Keys the bar hands over while this page shows; true when used
    function handleKey(event): bool {
        return false;
    }

    implicitHeight: childrenRect.height
}
