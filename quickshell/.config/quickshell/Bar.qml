// Top bar: workspaces on the left, clock in the middle, tray/network/CPU/battery on the right.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: bar

    // Nord, matching the notification cards, wofi and Hyprland borders
    readonly property color bg: "#2e3440"
    readonly property color fg: "#d8dee9"
    readonly property color muted: "#4c566a"
    readonly property color warning: "#ebcb8b"
    readonly property color urgent: "#bf616a"

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 26
    exclusionMode: ExclusionMode.Auto
    color: bg
    WlrLayershell.namespace: "bar"
    WlrLayershell.layer: WlrLayer.Top

    component BarText: Text {
        color: "#d8dee9"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }

    // ---- Tooltip, shared by every module

    function showTooltip(item, text) {
        tooltip.target = item;
        tooltip.text = text;
        tooltipAnchor.updateAnchor();
    }

    function hideTooltip(item) {
        if (tooltip.target === item)
            tooltip.target = null;
    }

    PopupWindow {
        id: tooltip
        property Item target: null
        property string text: ""

        visible: target !== null && text !== ""
        color: "transparent"
        implicitWidth: tooltipLabel.implicitWidth + 16
        implicitHeight: tooltipLabel.implicitHeight + 10

        anchor {
            id: tooltipAnchor
            window: bar
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1
            onAnchoring: {
                const target = tooltip.target;
                if (!target)
                    return;
                const p = bar.contentItem.mapFromItem(target, target.width / 2 - tooltip.implicitWidth / 2, target.height + 4);
                tooltipAnchor.rect.x = Math.round(p.x);
                tooltipAnchor.rect.y = Math.round(p.y);
            }
        }

        Rectangle {
            anchors.fill: parent
            color: bar.bg
            border.color: bar.muted
            border.width: 1
            radius: 6

            BarText {
                id: tooltipLabel
                anchors.centerIn: parent
                text: tooltip.text
            }
        }
    }

    // ---- Workspaces: 1-5 always, plus any other open ones up to 10

    readonly property var workspaceIds: {
        const ids = [1, 2, 3, 4, 5];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0 && ws.id <= 10 && !ids.includes(ws.id))
                ids.push(ws.id);
        }
        return ids.sort((a, b) => a - b);
    }

    function workspace(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id) ?? null;
    }

    RowLayout {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            leftMargin: 8
        }
        spacing: 3

        Repeater {
            model: bar.workspaceIds

            delegate: MouseArea {
                required property int modelData
                readonly property var workspace: bar.workspace(modelData)
                readonly property bool focused: Hyprland.focusedWorkspace?.id === modelData
                readonly property bool empty: !workspace || workspace.toplevels.values.length === 0

                Layout.fillHeight: true
                implicitWidth: Math.max(21, label.implicitWidth + 12)
                cursorShape: Qt.PointingHandCursor
                // Through hyprctl because this Hyprland is configured in Lua
                onClicked: Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${modelData} })`])

                BarText {
                    id: label
                    anchors.centerIn: parent
                    text: modelData === 10 ? "0" : String(modelData)
                    font.bold: parent.focused
                    color: parent.workspace?.urgent ? bar.urgent : parent.empty && !parent.focused ? bar.muted : bar.fg
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 2
                    visible: parent.focused
                    color: bar.fg
                }
            }
        }
    }

    // ---- Clock: click for the date

    property bool showDate: false

    function isoWeek(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    MouseArea {
        anchors.centerIn: parent
        width: clockText.implicitWidth
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.showDate = !bar.showDate

        BarText {
            id: clockText
            anchors.centerIn: parent
            text: bar.showDate
                ? `${Qt.formatDate(clock.date, "dd MMMM")} W${String(bar.isoWeek(clock.date)).padStart(2, "0")} ${clock.date.getFullYear()}`
                : Qt.formatDateTime(clock.date, "dddd HH:mm")
        }
    }

    // ---- Network, polled every 5s

    property var net: ({ type: "disconnected" })

    Process {
        id: netProc
        command: [Quickshell.shellDir + "/scripts/network-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    bar.net = JSON.parse(text);
                } catch (e) {
                    bar.net = { type: "disconnected" };
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    // ---- CPU usage from /proc/stat, polled every 5s

    property real cpuUsage: 0
    property var cpuLast: null

    Process {
        id: cpuProc
        command: ["head", "-1", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/).slice(1).map(Number);
                const idle = f[3] + f[4]; // idle + iowait
                const total = f.reduce((a, b) => a + b, 0);
                if (bar.cpuLast && total > bar.cpuLast.total)
                    bar.cpuUsage = 1 - (idle - bar.cpuLast.idle) / (total - bar.cpuLast.total);
                bar.cpuLast = { idle, total };
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }

    // ---- Right side

    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: Math.round(battery.percentage * 100)
    readonly property bool charging: battery.state === UPowerDeviceState.Charging

    RowLayout {
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
            rightMargin: 15
        }
        spacing: 15

        RowLayout {
            spacing: 12
            visible: SystemTray.items.values.length > 0

            Repeater {
                model: SystemTray.items

                delegate: MouseArea {
                    id: trayItem
                    required property SystemTrayItem modelData

                    implicitWidth: 12
                    implicitHeight: 12
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: containsMouse ? bar.showTooltip(this, modelData.tooltipTitle || modelData.title) : bar.hideTooltip(this)
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (modelData.hasMenu && (mouse.button === Qt.RightButton || modelData.onlyMenu)) {
                            const p = mapToItem(bar.contentItem, 0, height + 4);
                            modelData.display(bar, p.x, p.y);
                        } else {
                            modelData.activate();
                        }
                    }

                    IconImage {
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                        implicitSize: 12
                    }
                }
            }
        }

        MouseArea {
            implicitWidth: netIcon.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            onContainsMouseChanged: {
                const n = bar.net;
                const tip = n.type === "wifi" ? `${n.ssid || n.dev} (${n.signal}%)` : n.type === "ethernet" ? `${n.dev} ${n.ip}` : "Disconnected";
                containsMouse ? bar.showTooltip(this, tip) : bar.hideTooltip(this);
            }

            BarText {
                id: netIcon
                anchors.centerIn: parent
                text: bar.net.type === "wifi" ? ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(bar.net.signal / 20))] : bar.net.type === "ethernet" ? "󰈀" : "󰤮"
            }
        }

        MouseArea {
            implicitWidth: cpuIcon.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, `CPU ${Math.round(bar.cpuUsage * 100)}%`) : bar.hideTooltip(this)

            BarText {
                id: cpuIcon
                anchors.centerIn: parent
                text: ""
            }
        }

        BarText {
            visible: bar.battery.isLaptopBattery
            text: `${bar.batteryPercent}% ${bar.charging ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(bar.batteryPercent / 20))]}`
            color: bar.batteryPercent <= 10 ? bar.urgent : bar.batteryPercent <= 20 ? bar.warning : bar.fg
        }
    }
}
