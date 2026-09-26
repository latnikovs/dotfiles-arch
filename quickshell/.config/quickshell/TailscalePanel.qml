// Tailscale dropdown, from the VPN icon: an on/off switch, this device, the exit node, and the
// other devices in the tailnet. Click a device to copy its address, an exit node to route
// through it. Logged out, it opens the login page in the browser.
import QtQuick
import QtQuick.Layouts
import Quickshell

Dropdown {
    id: panel

    required property Tailscale tailscale
    readonly property var ts: tailscale
    // Address just copied, shown as "Copied" in its row for a moment
    property string copied: ""

    onOpenChanged: {
        ts.watching = open;
        copied = "";
        if (open)
            ts.refresh();
    }

    function copy(ip) {
        ts.copy(ip);
        copied = ip;
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer
        interval: 1500
        onTriggered: panel.copied = ""
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            BarText {
                Layout.fillWidth: true
                text: "Tailscale"
                font.bold: true
            }

            ToggleSwitch {
                visible: panel.ts.running || panel.ts.backendState === "Stopped"
                checked: panel.ts.running
                onToggled: panel.ts.setRunning(!panel.ts.running)
            }
        }

        BarText {
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.WordWrap
            color: panel.bar.muted
            text: ({
                    Stopped: "Disconnected",
                    Starting: "Connecting…",
                    NeedsMachineAuth: "Waiting for this device to be approved in the admin console",
                    NeedsLogin: panel.ts.loggingIn ? "Finish logging in in the browser" : "Logged out",
                    NoState: "Starting…"
                })[panel.ts.backendState] ?? ""
        }

        LinkText {
            visible: panel.ts.backendState === "NeedsLogin"
            text: panel.ts.loggingIn ? "Open the login page again" : "Log in…"
            onClicked: panel.ts.startLogin()
        }

        Caption {
            visible: panel.ts.running
            text: panel.ts.tailnet !== "" ? `THIS DEVICE · ${panel.ts.tailnet.toUpperCase()}` : "THIS DEVICE"
        }

        NodeRow {
            visible: panel.ts.running
            node: panel.ts.self
        }

        Caption {
            visible: panel.ts.running && panel.ts.exitNodeOptions.length > 0
            text: "EXIT NODE"
        }

        Repeater {
            model: panel.ts.running && panel.ts.exitNodeOptions.length > 0 ? [null, ...panel.ts.exitNodeOptions] : []
            delegate: ExitNodeRow {}
        }

        Caption {
            visible: panel.ts.running
            text: panel.ts.peers.length > 0 ? "DEVICES" : "NO OTHER DEVICES"
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 240)
            visible: panel.ts.running && count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: panel.ts.running ? panel.ts.peers : []
            delegate: NodeRow {
                required property var modelData
                width: ListView.view.width
                node: modelData
            }
        }

        Caption {
            Layout.fillWidth: true
            visible: panel.ts.error !== ""
            wrapMode: Text.WordWrap
            text: panel.ts.error
            color: panel.bar.urgent
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: panel.bar.fg
            opacity: 0.12
        }

        // Devices, keys, ACLs, DNS: the web admin console
        LinkText {
            text: "Admin console…"
            onClicked: {
                panel.open = false;
                Quickshell.execDetached(["xdg-open", "https://login.tailscale.com/admin/machines"]);
            }
        }
    }

    component LinkText: BarText {
        id: link
        signal clicked

        color: linkArea.containsMouse ? panel.bar.accent : Qt.darker(panel.bar.fg, 1.4)

        MouseArea {
            id: linkArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    // A device: online dot, name, and address · OS; click copies the address
    component NodeRow: Rectangle {
        id: row
        property var node: null
        readonly property string ip: panel.ts.ipv4Of(node)

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + 12
        radius: 6
        color: rowArea.containsMouse ? panel.bar.muted : "transparent"

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
                text: "●"
                font.pixelSize: 9
                color: row.node?.Online ? panel.bar.accent : panel.bar.muted
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                BarText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: panel.ts.nameOf(row.node)
                    color: row.node?.Online ? panel.bar.fg : Qt.darker(panel.bar.fg, 1.4)
                }

                Caption {
                    text: panel.copied !== "" && panel.copied === row.ip ? "Copied"
                        : [row.ip, row.node?.OS ?? ""].filter(s => s !== "").join(" · ")
                }
            }

            BarText {
                visible: rowArea.containsMouse
                text: "󰆏"
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.ip !== "") panel.copy(row.ip)
        }
    }

    // An exit node choice, or "None" for modelData null
    component ExitNodeRow: Rectangle {
        id: exitRow
        required property var modelData
        readonly property bool selected: modelData ? modelData.ExitNode : panel.ts.exitNode === null

        Layout.fillWidth: true
        implicitHeight: exitLayout.implicitHeight + 12
        radius: 6
        color: exitArea.containsMouse ? panel.bar.muted : "transparent"

        RowLayout {
            id: exitLayout
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 10
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 10

            BarText {
                text: exitRow.selected ? "󰄬" : ""
                Layout.preferredWidth: 12
                color: panel.bar.accent
            }

            BarText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: exitRow.modelData ? panel.ts.nameOf(exitRow.modelData) : "None"
                color: exitRow.selected ? panel.bar.accent : exitRow.modelData && !exitRow.modelData.Online ? Qt.darker(panel.bar.fg, 1.4) : panel.bar.fg
                font.bold: exitRow.selected
            }

            Caption {
                visible: exitRow.modelData !== null && !exitRow.modelData.Online
                text: "offline"
            }
        }

        MouseArea {
            id: exitArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: panel.ts.busy ? Qt.BusyCursor : Qt.PointingHandCursor
            onClicked: if (!exitRow.selected) panel.ts.useExitNode(exitRow.modelData ? panel.ts.ipv4Of(exitRow.modelData) : "")
        }
    }
}
