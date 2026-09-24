// Bluetooth dropdown, from the Bluetooth icon (BlueZ): an on/off switch, paired devices, and
// devices found nearby while it's open. Click a device to connect, disconnect, or pair.
// There's no pairing agent, so devices that show a PIN (keyboards) need `bluetoothctl`.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

Dropdown {
    id: panel

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var devices: adapter ? adapter.devices.values : []
    // Connected first; nameless devices (their name is only their address) are left out
    readonly property var paired: devices.filter(d => d.paired).sort((a, b) => b.connected - a.connected || a.name.localeCompare(b.name))
    readonly property var nearby: devices.filter(d => !d.paired && d.deviceName !== "").sort((a, b) => a.name.localeCompare(b.name))

    // Pairing, then trust and connect once it's done
    property var pairing: null

    function activate(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            pairing = device;
            device.pair();
        }
    }

    function deviceIcon(icon) {
        if (icon.startsWith("audio-head"))
            return "󰋋";
        if (icon.startsWith("audio"))
            return "󰓃";
        if (icon === "input-keyboard")
            return "󰌌";
        if (icon === "input-mouse")
            return "󰍽";
        if (icon === "input-gaming")
            return "󰊴";
        if (icon === "phone")
            return "󰏲";
        return "󰂯";
    }

    // Look for devices while open; the Binding stops the search when it closes
    Binding {
        target: panel.adapter
        property: "discovering"
        value: true
        when: panel.open && panel.powered
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        BarText {
            visible: panel.adapter === null
            text: "No Bluetooth adapter"
            color: panel.bar.muted
        }

        RowLayout {
            Layout.fillWidth: true
            visible: panel.adapter !== null

            BarText {
                Layout.fillWidth: true
                text: "Bluetooth"
                font.bold: true
            }

            ToggleSwitch {
                checked: panel.powered
                onToggled: panel.adapter.enabled = !panel.powered
            }
        }

        BarText {
            visible: panel.adapter?.state === BluetoothAdapterState.Blocked
            text: "Blocked by rfkill"
            color: panel.bar.muted
        }

        Caption {
            visible: panel.powered && panel.paired.length > 0
            text: "PAIRED"
        }

        Repeater {
            model: panel.powered ? panel.paired : []
            delegate: DeviceRow {}
        }

        Caption {
            visible: panel.powered
            text: panel.nearby.length > 0 ? "NEARBY" : "SEARCHING…"
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 240)
            visible: panel.powered && count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: panel.powered ? panel.nearby : []
            delegate: DeviceRow {
                width: ListView.view.width
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row
        required property var modelData
        readonly property var device: modelData

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + 12
        radius: 6
        color: rowArea.containsMouse ? panel.bar.muted : "transparent"

        Connections {
            target: row.device
            function onPairedChanged() {
                if (row.device.paired && panel.pairing === row.device) {
                    panel.pairing = null;
                    row.device.trusted = true;
                    row.device.connect();
                }
            }
            function onPairingChanged() {
                // Pairing ended without pairing: failed or cancelled
                if (!row.device.pairing && !row.device.paired && panel.pairing === row.device)
                    panel.pairing = null;
            }
        }

        RowLayout {
            id: rowLayout
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 10
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 10

            BarText {
                text: panel.deviceIcon(row.device.icon)
                font.pixelSize: 14
                color: row.device.connected ? panel.bar.accent : panel.bar.fg
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                BarText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: row.device.name
                    color: row.device.connected ? panel.bar.accent : panel.bar.fg
                    font.bold: row.device.connected
                }

                Caption {
                    visible: text !== ""
                    text: {
                        const d = row.device;
                        if (d.pairing)
                            return "Pairing…";
                        if (d.state === BluetoothDeviceState.Connecting)
                            return "Connecting…";
                        if (d.state === BluetoothDeviceState.Disconnecting)
                            return "Disconnecting…";
                        if (d.connected)
                            return d.batteryAvailable ? `Connected · ${Math.round(d.battery * 100)}%` : "Connected";
                        return "";
                    }
                }
            }

            // Forget (unpair): only for paired devices, on hover
            BarText {
                visible: row.device.paired && (rowArea.containsMouse || forgetArea.containsMouse)
                text: "󰆴"
                color: forgetArea.containsMouse ? panel.bar.urgent : panel.bar.fg

                MouseArea {
                    id: forgetArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.device.forget()
                }
            }
        }

        // Below the forget button, which takes its own clicks
        MouseArea {
            id: rowArea
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.activate(row.device)
        }
    }
}
