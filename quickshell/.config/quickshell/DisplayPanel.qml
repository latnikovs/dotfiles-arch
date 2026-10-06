// Display dropdown, from the monitor icon, after Omarchy's: this bar's monitor, its mode when the
// machine has presets (~/.config/hypr/display-modes, scripts/monitor-mode), its scale
// (scripts/monitor-scale, which SUPER + CTRL + / cycles) and brightness (scripts/brightness).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Dropdown {
    id: panel

    readonly property var monitor: Hyprland.monitorFor(panel.bar.screen)
    readonly property real scale: monitor?.scale ?? 1
    readonly property var scales: [1, 1.25, 1.6, 2]
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"

    panelWidth: 300

    onOpenChanged: if (open) Hyprland.refreshMonitors()

    // "MODE NAME" lines, from machines/<machine>.display-modes; none on most machines
    property var modes: []

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/display-modes"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: panel.modes = text().split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#")).map(l => {
            const [mode, ...name] = l.split(/\s+/);
            return { mode: mode, size: mode.split("@")[0], name: name.join(" ") || mode };
        })
        onLoadFailed: panel.modes = []
    }

    function setMode(mode) {
        Quickshell.execDetached([scripts + "monitor-mode", mode, monitor.name]);
        refresh.restart();
    }

    function setScale(s) {
        Quickshell.execDetached([scripts + "monitor-scale", String(s), monitor.name]);
        refresh.restart();
    }

    // The scale change reaches Hyprland's monitor list a moment later
    Timer {
        id: refresh
        interval: 300
        onTriggered: Hyprland.refreshMonitors()
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            BarText {
                Layout.fillWidth: true
                text: "Display"
                font.bold: true
            }

            Caption {
                text: panel.monitor?.name ?? ""
            }
        }

        Caption {
            visible: panel.modes.length > 0
            text: panel.monitor ? `MODE · ${panel.monitor.width}×${panel.monitor.height}` : "MODE"
        }

        RowLayout {
            visible: panel.modes.length > 0
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: panel.modes
                delegate: Chip {
                    required property var modelData
                    text: modelData.name
                    current: panel.monitor ? modelData.size === `${panel.monitor.width}x${panel.monitor.height}` : false
                    onClicked: panel.setMode(modelData.mode)
                }
            }
        }

        Caption {
            // width and height are the mode's pixels
            text: panel.monitor
                ? `SCALE · ${Math.round(panel.monitor.width / panel.scale)}×${Math.round(panel.monitor.height / panel.scale)} LOGICAL`
                : "SCALE"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: panel.scales
                delegate: Chip {
                    required property real modelData
                    text: `${modelData}×`
                    current: Math.abs(panel.scale - modelData) < 0.01
                    onClicked: panel.setScale(modelData)
                }
            }
        }

        Caption {
            text: "BRIGHTNESS"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Chip {
                text: "󰃞  Dimmer"
                onClicked: Quickshell.execDetached([panel.scripts + "brightness", "down", panel.monitor.name])
            }

            Chip {
                text: "󰃠  Brighter"
                onClicked: Quickshell.execDetached([panel.scripts + "brightness", "up", panel.monitor.name])
            }
        }
    }

    // A button filling its share of the row; accent outline when it's the current choice
    component Chip: Rectangle {
        id: chip
        property alias text: label.text
        property bool current: false
        signal clicked

        Layout.fillWidth: true
        implicitHeight: label.implicitHeight + 12
        radius: 6
        color: chipArea.containsMouse ? panel.bar.muted : "transparent"
        border.width: 1
        border.color: current ? panel.bar.accent : Qt.rgba(panel.bar.fg.r, panel.bar.fg.g, panel.bar.fg.b, 0.15)

        BarText {
            id: label
            anchors.centerIn: parent
            color: chip.current ? panel.bar.accent : panel.bar.fg
            font.bold: chip.current
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
