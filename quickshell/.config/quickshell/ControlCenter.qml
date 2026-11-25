// Control center, from the sliders icon next to the bell, after macOS's: a tile per setting the bar
// no longer shows all the time (Bar.qml shows each icon again only while its state is unusual).
// Left click on a tile flips it; the chevron (or a right click) slides its page in (network,
// Bluetooth, Tailscale, Syncthing, display, reminders: the *Panel.qml pages), and the card grows or
// shrinks to fit. "Control center" at the top of a page, or Esc, goes back to the tiles. The bar's
// icons and keys open it straight on a page, where Esc closes it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Dropdown {
    id: panel

    required property Tailscale tailscale
    required property Syncthing syncthing
    required property Caffeine caffeine
    required property Reminders reminders
    required property Notifications notifications

    readonly property var ts: tailscale
    readonly property var st: syncthing
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"

    panelWidth: 360

    // "" on the tiles, else the page showing
    property string page: ""
    // Whether the page slid in from the tiles, so Esc goes back to them rather than closing
    property bool fromTiles: false
    readonly property var pages: ({
        network: networkPage,
        bluetooth: bluetoothPage,
        tailscale: tailscalePage,
        syncthing: syncthingPage,
        display: displayPage,
        reminders: remindersPage
    })
    readonly property Item current: page === "" ? home : pages[page]
    // Opened straight on a page, the card shows it at once instead of sliding it in
    readonly property bool animate: visible

    function show(name: string): void {
        if (page === "")
            fromTiles = open;
        page = name;
    }

    function back(): void {
        page = "";
        fromTiles = false;
    }

    function handleKey(event): bool {
        if (page !== "" && pages[page].handleKey(event))
            return true;
        if (event.key === Qt.Key_Escape && fromTiles) {
            back();
            return true;
        }
        return false;
    }

    // Back on the tiles once the card has slid away
    onVisibleChanged: if (!visible) back()

    // ---- Night light (hyprsunset): on while it runs warmer than 6500K, as scripts/nightlight decides

    property bool nightLight: false

    onOpenChanged: if (open) nightProc.running = true

    Process {
        id: nightProc
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null || exit 0; [ \"$(hyprctl hyprsunset identity get)\" = true ] && exit 0; [ \"$(hyprctl hyprsunset temperature)\" -lt 6500 ] && echo on"]
        stdout: StdioCollector {
            onStreamFinished: panel.nightLight = text.trim() === "on"
        }
    }

    // scripts/nightlight may start hyprsunset first, so the state is read back after a moment
    Timer {
        id: nightRefresh
        interval: 1500
        onTriggered: nightProc.running = true
    }

    Item {
        width: parent.width
        height: header.height + 10 + panel.current.implicitHeight
        clip: true

        Behavior on height {
            enabled: panel.animate
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // The title on the tiles; on a page, the way back to them
        Item {
            id: header
            width: parent.width
            height: 18

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Control center"
                font.bold: true
                opacity: panel.page === "" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: panel.animate
                    NumberAnimation {
                        duration: 160
                    }
                }
            }

            MouseArea {
                id: backArea
                width: backRow.implicitWidth + 8
                height: parent.height
                x: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                opacity: panel.page === "" ? 0 : 1
                visible: opacity > 0
                onClicked: panel.back()

                Behavior on opacity {
                    enabled: panel.animate
                    NumberAnimation {
                        duration: 160
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, backArea.containsMouse ? 0.12 : 0)
                }

                Row {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: 4

                    BarText {
                        text: "󰅁"
                        color: backArea.containsMouse ? Theme.fg : Theme.dim
                    }

                    BarText {
                        text: "Control center"
                        color: backArea.containsMouse ? Theme.fg : Theme.dim
                    }
                }
            }
        }

        Item {
            id: stage
            y: header.height + 10
            width: parent.width
            height: panel.current.implicitHeight

            ColumnLayout {
                id: home
                width: parent.width
                spacing: 10
                x: panel.page === "" ? 0 : -width
                opacity: panel.page === "" ? 1 : 0
                visible: opacity > 0

                Behavior on x {
                    enabled: panel.animate
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    enabled: panel.animate
                    NumberAnimation {
                        duration: 160
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    Tile {
                        icon: panel.bar.wiredUp ? "󰈀" : !Networking.wifiEnabled ? "󰤮"
                            : panel.bar.wifiNetwork ? panel.bar.wifiIcon(panel.bar.wifiNetwork.signalStrength) : "󰤯"
                        label: panel.bar.wiredUp ? "Ethernet" : "Wi-Fi"
                        status: panel.bar.wiredUp ? panel.bar.wiredUp.name
                            : !Networking.wifiEnabled ? "Off"
                            : panel.bar.wifiNetwork ? panel.bar.wifiNetwork.name : "Not connected"
                        active: panel.bar.wiredUp !== null || panel.bar.wifiNetwork !== null
                        tint: Theme.blue
                        // Wired has nothing to flip, so the tile opens the list instead
                        onToggled: panel.bar.wiredUp || !panel.bar.wifiDevice ? panel.show("network") : Networking.wifiEnabled = !Networking.wifiEnabled
                        onDetails: panel.show("network")
                    }

                    Tile {
                        visible: panel.bar.btAdapter !== null
                        readonly property var connected: panel.bar.btConnected
                        icon: !panel.bar.btAdapter?.enabled ? "󰂲" : connected.length > 0 ? "󰂱" : "󰂯"
                        label: "Bluetooth"
                        status: !panel.bar.btAdapter?.enabled ? "Off"
                            : connected.length > 0 ? connected.map(d => d.name).join(", ") : "On"
                        active: panel.bar.btAdapter?.enabled ?? false
                        tint: Theme.blue
                        onToggled: panel.bar.btAdapter.enabled = !panel.bar.btAdapter.enabled
                        onDetails: panel.show("bluetooth")
                    }

                    Tile {
                        visible: panel.ts.available
                        icon: "󰖂"
                        label: "Tailscale"
                        status: panel.ts.running ? (panel.ts.exitNode ? `Exit node ${panel.ts.nameOf(panel.ts.exitNode)}` : panel.ts.ipv4Of(panel.ts.self))
                            : panel.ts.backendState === "NeedsLogin" ? "Logged out" : "Off"
                        active: panel.ts.running
                        tint: panel.ts.exitNode ? Theme.green : Theme.blue
                        onToggled: {
                            if (panel.ts.running || panel.ts.backendState === "Stopped")
                                panel.ts.setRunning(!panel.ts.running);
                            else
                                panel.show("tailscale");
                        }
                        onDetails: panel.show("tailscale")
                    }

                    Tile {
                        visible: panel.st.available
                        icon: panel.st.errorCount > 0 ? "󰓧" : panel.st.paused || panel.st.connectedCount === 0 ? "󰓨" : "󰓦"
                        label: "Syncthing"
                        status: panel.st.paused ? "Paused"
                            : panel.st.errorCount > 0 ? `${panel.st.errorCount} failed`
                            : panel.st.devices.length === 0 ? "No devices"
                            : panel.st.connectedCount === 0 ? "No device connected"
                            : panel.st.syncing ? "Syncing" : "Up to date"
                        active: !panel.st.paused && panel.st.devices.length > 0
                        tint: panel.st.errorCount > 0 ? Theme.urgent : panel.st.syncing ? Theme.green : Theme.blue
                        onToggled: {
                            if (panel.st.devices.length > 0)
                                panel.st.setPaused(!panel.st.paused);
                            else
                                panel.show("syncthing");
                        }
                        onDetails: panel.show("syncthing")
                    }

                    Tile {
                        icon: "󰅶"
                        label: "Caffeine"
                        status: panel.caffeine.on ? "Screen stays awake" : "Off"
                        active: panel.caffeine.on
                        tint: Theme.warning
                        hasDetails: false
                        onToggled: panel.caffeine.on = !panel.caffeine.on
                    }

                    Tile {
                        icon: panel.notifications.dnd ? "󰂛" : "󰂚"
                        label: "Silence"
                        status: panel.notifications.dnd ? "On" : "Off"
                        active: panel.notifications.dnd
                        tint: Theme.purple
                        hasDetails: false
                        onToggled: panel.notifications.dnd = !panel.notifications.dnd
                    }

                    Tile {
                        icon: Theme.dark ? "󰖔" : "󰖙"
                        label: "Appearance"
                        status: Theme.dark ? "Dark" : "Light"
                        active: true
                        tint: Theme.dark ? Theme.purple : Theme.orange
                        hasDetails: false
                        // Straight to scripts/theme if darkman isn't running (it starts with Hyprland)
                        onToggled: Quickshell.execDetached(["sh", "-c", `darkman toggle || ${panel.scripts}theme ${Theme.dark ? "light" : "dark"}`])
                    }

                    Tile {
                        icon: "󰖚"
                        label: "Night light"
                        status: panel.nightLight ? "On" : "Off"
                        active: panel.nightLight
                        tint: Theme.orange
                        hasDetails: false
                        onToggled: {
                            panel.nightLight = !panel.nightLight;
                            Quickshell.execDetached([panel.scripts + "nightlight"]);
                            nightRefresh.restart();
                        }
                    }
                }

                // Wide rows: things that open rather than flip

                Tile {
                    Layout.fillWidth: true
                    readonly property var monitor: panel.bar.displayMonitor
                    icon: "󰍹"
                    label: "Display"
                    status: `${monitor?.name ?? ""} · scale ${Math.round((monitor?.scale ?? 1) * 100) / 100}×`
                    active: true
                    tint: Theme.teal
                    onToggled: panel.show("display")
                    onDetails: panel.show("display")
                }

                Tile {
                    Layout.fillWidth: true
                    readonly property var next: panel.reminders.next
                    icon: "󰀠"
                    label: next === null ? "Reminders" : next.message
                    status: next === null ? "None set · click to add one"
                        : `in ${panel.reminders.left(next)}` + (panel.reminders.count > 1 ? ` · ${panel.reminders.count - 1} more` : "")
                    active: next !== null
                    tint: Theme.warning
                    onToggled: {
                    if (panel.reminders.count > 0) {
                        panel.show("reminders");
                    } else {
                        panel.bar.closePanels();
                        panel.reminders.prompt();
                    }
                }
                    onDetails: {
                        panel.bar.closePanels();
                        panel.reminders.prompt();
                    }
                    detailsIcon: "󰐕"
                }
            }

            Slot {
                name: "network"
                NetworkPanel {
                    id: networkPage
                    width: parent.width
                    bar: panel.bar
                    open: panel.open && panel.page === "network"
                    onCloseRequested: panel.open = false
                }
            }

            Slot {
                name: "bluetooth"
                BluetoothPanel {
                    id: bluetoothPage
                    width: parent.width
                    bar: panel.bar
                    open: panel.open && panel.page === "bluetooth"
                    onCloseRequested: panel.open = false
                }
            }

            Slot {
                name: "tailscale"
                TailscalePanel {
                    id: tailscalePage
                    width: parent.width
                    bar: panel.bar
                    tailscale: panel.tailscale
                    open: panel.open && panel.page === "tailscale"
                    onCloseRequested: panel.open = false
                }
            }

            Slot {
                name: "syncthing"
                SyncthingPanel {
                    id: syncthingPage
                    width: parent.width
                    bar: panel.bar
                    syncthing: panel.syncthing
                    open: panel.open && panel.page === "syncthing"
                    onCloseRequested: panel.open = false
                }
            }

            Slot {
                name: "display"
                DisplayPanel {
                    id: displayPage
                    width: parent.width
                    bar: panel.bar
                    open: panel.open && panel.page === "display"
                    onCloseRequested: panel.open = false
                }
            }

            Slot {
                name: "reminders"
                RemindersPanel {
                    id: remindersPage
                    width: parent.width
                    bar: panel.bar
                    reminders: panel.reminders
                    open: panel.open && panel.page === "reminders"
                    // With the last one gone, back to the tiles
                    onCloseRequested: panel.reminders.count === 0 ? panel.back() : panel.open = false
                }
            }
        }
    }

    // Holds one page, pushed in from the right while it's the one showing; it leaves to the right
    // going back to the tiles, to the left for another page
    component Slot: Item {
        required property string name
        readonly property bool showing: panel.page === name

        width: stage.width
        height: childrenRect.height
        x: showing ? 0 : panel.page === "" ? width : -width
        opacity: showing ? 1 : 0
        visible: opacity > 0

        Behavior on x {
            enabled: panel.animate
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            enabled: panel.animate
            NumberAnimation {
                duration: 160
            }
        }
    }

    // A rounded tile: a round icon, filled in its tint while on, a label and a status line.
    // Left click flips it; the chevron or a right click opens its dropdown.
    component Tile: Rectangle {
        id: tile

        property string icon
        property string label
        property string status
        property bool active
        property color tint: Theme.accent
        property bool hasDetails: true
        property string detailsIcon: "󰅂"
        signal toggled
        signal details

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 50
        radius: 10
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, area.containsMouse ? 0.12 : 0.05)

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => mouse.button === Qt.RightButton && tile.hasDetails ? tile.details() : tile.toggled()
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 9
                rightMargin: tile.hasDetails ? 4 : 10
            }
            spacing: 9

            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: 15
                color: tile.active ? tile.tint : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.1)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                BarText {
                    anchors.centerIn: parent
                    text: tile.icon
                    font.pixelSize: 14
                    color: tile.active ? Theme.bg : Theme.fg
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                BarText {
                    Layout.fillWidth: true
                    text: tile.label
                    font.bold: true
                    elide: Text.ElideRight
                }

                BarText {
                    Layout.fillWidth: true
                    text: tile.status
                    color: Theme.dim
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            // Its own click area, above the tile's
            MouseArea {
                visible: tile.hasDetails
                implicitWidth: 22
                Layout.fillHeight: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.details()

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, parent.containsMouse ? 0.15 : 0)
                }

                BarText {
                    anchors.centerIn: parent
                    text: tile.detailsIcon
                    color: parent.containsMouse ? Theme.fg : Theme.dim
                }
            }
        }
    }
}
