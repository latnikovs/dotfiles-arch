// Network dropdown, from the network icon (NetworkManager): wired links with their address,
// then Wi-Fi with an on/off switch and the networks in range. Click a network to connect or
// disconnect; secured networks ask for the password in the row (Ctrl + V pastes it).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Dropdown {
    id: panel

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.filter(d => d.type === DeviceType.Wired)
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    // Connected first, then strongest; hidden networks have no name to show
    readonly property var networks: wifi ? wifi.networks.values.filter(n => n.name !== "")
        .sort((a, b) => b.connected - a.connected || b.signalStrength - a.signalStrength) : []

    // Wi-Fi password being typed, for passwordFor
    property var passwordFor: null
    property string password: ""
    property bool showPassword: false
    // Last failure, shown under its network
    property var errorFor: null
    property string error: ""

    // IPv4 address per interface, from `ip`: NetworkManager's objects don't carry it
    property var addresses: ({})

    readonly property var pskTypes: [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae]

    function activate(network) {
        errorFor = null;
        if (network.connected) {
            network.disconnect();
        } else if (network.known || !pskTypes.includes(network.security)) {
            // A saved or open network; a stale saved password comes back as NoSecrets
            network.connect();
        } else {
            askPassword(network);
        }
    }

    function askPassword(network) {
        passwordFor = network;
        password = "";
        showPassword = false;
    }

    function submitPassword() {
        if (password === "")
            return;
        passwordFor.connectWithPsk(password);
        passwordFor = null;
        errorFor = null;
        password = "";
    }

    function failed(network, reason) {
        if (reason === ConnectionFailReason.NoSecrets && pskTypes.includes(network.security)) {
            askPassword(network);
            error = "Wrong or missing password";
        } else {
            error = ({
                [ConnectionFailReason.WifiClientDisconnected]: "Disconnected by the network",
                [ConnectionFailReason.WifiAuthTimeout]: "Timed out, check the password",
                [ConnectionFailReason.WifiNetworkLost]: "Network went out of range"
            })[reason] ?? "Couldn't connect";
        }
        errorFor = network;
    }

    // The password field takes every key while it's open
    function handleKey(event): bool {
        if (!passwordFor)
            return false;
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Escape)
            passwordFor = null;
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            submitPassword();
        else if (event.key === Qt.Key_Backspace)
            password = ctrl ? "" : password.slice(0, -1);
        else if (ctrl && event.key === Qt.Key_V)
            pasteProc.running = true;
        else if (!ctrl && event.text.length > 0 && event.text >= " ")
            password += event.text;
        return true;
    }

    onOpenChanged: {
        if (open) {
            addressProc.running = true;
        } else {
            passwordFor = null;
            errorFor = null;
        }
    }

    // Scan while open; the Binding puts the scanner back when it closes
    Binding {
        target: panel.wifi
        property: "scannerEnabled"
        value: true
        when: panel.open && panel.wifi !== null && Networking.wifiEnabled
    }

    Process {
        id: addressProc
        command: ["ip", "-j", "-4", "addr"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {};
                    for (const link of JSON.parse(text))
                        map[link.ifname] = link.addr_info?.[0]?.local ?? "";
                    panel.addresses = map;
                } catch (e) {
                    panel.addresses = {};
                }
            }
        }
    }

    // DHCP finishes after the device reports connected, so look again shortly after
    Timer {
        id: addressRetry
        interval: 1500
        onTriggered: addressProc.running = true
    }

    Process {
        id: pasteProc
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (panel.passwordFor)
                    panel.password += text.replace(/[\r\n]/g, "");
            }
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        BarText {
            visible: Networking.backend === NetworkBackendType.None
            text: "NetworkManager isn't running"
            color: panel.bar.muted
        }

        // ---- Wired

        Repeater {
            model: panel.wired

            delegate: RowLayout {
                id: wiredRow
                required property var modelData

                Layout.fillWidth: true
                spacing: 12

                Connections {
                    target: wiredRow.modelData
                    function onConnectedChanged() {
                        addressProc.running = true;
                        addressRetry.restart();
                    }
                }

                BarText {
                    text: "󰈀"
                    font.pixelSize: 20
                    color: wiredRow.modelData.connected ? panel.bar.fg : panel.bar.muted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    BarText {
                        text: `Ethernet · ${wiredRow.modelData.name}`
                        font.bold: true
                    }

                    Caption {
                        text: {
                            const d = wiredRow.modelData;
                            if (d.connected) {
                                const speed = d.linkSpeed >= 1000 ? `${d.linkSpeed / 1000} Gb/s` : d.linkSpeed > 0 ? `${d.linkSpeed} Mb/s` : "";
                                return [panel.addresses[d.name], speed].filter(Boolean).join(" · ") || "Connected";
                            }
                            if (d.state === ConnectionState.Connecting)
                                return "Connecting…";
                            return d.hasLink ? "Disconnected" : "Cable unplugged";
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            visible: panel.wired.length > 0 && panel.wifi !== null
            color: panel.bar.fg
            opacity: 0.12
        }

        // ---- Wi-Fi

        RowLayout {
            Layout.fillWidth: true
            visible: panel.wifi !== null

            BarText {
                Layout.fillWidth: true
                text: "Wi-Fi"
                font.bold: true
            }

            ToggleSwitch {
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        BarText {
            visible: panel.wifi !== null && !Networking.wifiHardwareEnabled
            text: "Turned off by a hardware switch"
            color: panel.bar.muted
        }

        BarText {
            visible: panel.wifi !== null && Networking.wifiEnabled && panel.networks.length === 0
            text: "Searching…"
            color: panel.bar.muted
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
            visible: panel.wifi !== null && Networking.wifiEnabled && count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: panel.networks

            delegate: ColumnLayout {
                id: net
                required property var modelData
                readonly property bool asking: panel.passwordFor === modelData
                readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe

                width: ListView.view.width
                spacing: 4

                Connections {
                    target: net.modelData
                    function onConnectionFailed(reason) {
                        panel.failed(net.modelData, reason);
                    }
                    function onConnectedChanged() {
                        addressProc.running = true;
                        addressRetry.restart();
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: netRow.implicitHeight + 12
                    radius: 6
                    color: netArea.containsMouse || net.asking ? panel.bar.muted : "transparent"

                    RowLayout {
                        id: netRow
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 10
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 10

                        BarText {
                            text: panel.bar.wifiIcon(net.modelData.signalStrength)
                            font.pixelSize: 14
                            color: net.modelData.connected ? panel.bar.accent : panel.bar.fg
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            BarText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: net.modelData.name
                                color: net.modelData.connected ? panel.bar.accent : panel.bar.fg
                                font.bold: net.modelData.connected
                            }

                            Caption {
                                readonly property string address: panel.addresses[panel.wifi?.name] ?? ""
                                visible: text !== ""
                                text: net.modelData.stateChanging ? (net.modelData.connected ? "Disconnecting…" : "Connecting…")
                                    : net.modelData.connected ? (address || "Connected")
                                    : net.modelData.known ? "Saved" : ""
                            }
                        }

                        // Forget: only for saved networks, on hover
                        BarText {
                            visible: net.modelData.known && (netArea.containsMouse || forgetArea.containsMouse)
                            text: "󰆴"
                            color: forgetArea.containsMouse ? panel.bar.urgent : panel.bar.fg

                            MouseArea {
                                id: forgetArea
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: net.modelData.forget()
                            }
                        }

                        BarText {
                            visible: net.secured
                            text: "󰌾"
                            color: Qt.darker(panel.bar.fg, 1.4)
                        }
                    }

                    // Below the forget button, which takes its own clicks
                    MouseArea {
                        id: netArea
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.activate(net.modelData)
                    }
                }

                // Password, typed through handleKey
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    visible: net.asking
                    implicitHeight: 30
                    radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: panel.bar.accent

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 8
                        }
                        spacing: 8

                        BarText {
                            Layout.fillWidth: true
                            elide: Text.ElideLeft
                            text: panel.password === "" ? "Password" : panel.showPassword ? panel.password : "•".repeat(panel.password.length)
                            color: panel.password === "" ? panel.bar.muted : panel.bar.fg
                        }

                        // Cursor
                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 14
                            color: panel.bar.fg
                            visible: panel.password !== ""
                        }

                        BarText {
                            text: panel.showPassword ? "󰈉" : "󰈈"
                            color: eyeArea.containsMouse ? panel.bar.accent : Qt.darker(panel.bar.fg, 1.4)

                            MouseArea {
                                id: eyeArea
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.showPassword = !panel.showPassword
                            }
                        }

                        BarText {
                            text: "󰌑"
                            color: joinArea.containsMouse ? panel.bar.accent : panel.bar.fg

                            MouseArea {
                                id: joinArea
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.submitPassword()
                            }
                        }
                    }
                }

                Caption {
                    Layout.leftMargin: 10
                    visible: panel.errorFor === net.modelData && panel.error !== ""
                    text: panel.error
                    color: panel.bar.urgent
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: panel.bar.fg
            opacity: 0.12
        }

        // VPNs, static addresses, hidden and enterprise Wi-Fi
        BarText {
            text: "Network settings…"
            color: settingsArea.containsMouse ? panel.bar.accent : Qt.darker(panel.bar.fg, 1.4)

            MouseArea {
                id: settingsArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.open = false;
                    Quickshell.execDetached(["nm-connection-editor"]);
                }
            }
        }
    }
}
