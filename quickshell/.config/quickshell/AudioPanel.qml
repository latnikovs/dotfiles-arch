// Audio dropdown, from the speaker icon: output and input volume, each with a device picker,
// then a volume slider for every app playing sound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Dropdown {
    id: panel
    panelWidth: 380

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)

    function label(node) {
        return node.description || node.nickname || node.name;
    }

    // Volume and mute are only valid on bound nodes
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource, ...panel.streams]
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        Caption {
            text: "OUTPUT"
        }

        VolumeRow {
            visible: Pipewire.defaultAudioSink !== null
            node: Pipewire.defaultAudioSink
        }

        DeviceList {
            devices: panel.sinks
            current: Pipewire.defaultAudioSink
            onPicked: node => Pipewire.preferredDefaultAudioSink = node
        }

        BarText {
            visible: panel.sinks.length === 0
            text: "No output devices"
            color: panel.bar.muted
        }

        Divider {
            visible: panel.sources.length > 0
        }

        Caption {
            visible: panel.sources.length > 0
            text: "INPUT"
        }

        VolumeRow {
            visible: panel.sources.length > 0
            node: Pipewire.defaultAudioSource
            input: true
        }

        DeviceList {
            visible: panel.sources.length > 0
            devices: panel.sources
            current: Pipewire.defaultAudioSource
            onPicked: node => Pipewire.preferredDefaultAudioSource = node
        }

        Divider {
            visible: panel.streams.length > 0
        }

        Caption {
            visible: panel.streams.length > 0
            text: "APPLICATIONS"
        }

        Repeater {
            model: panel.streams

            delegate: ColumnLayout {
                id: stream
                required property PwNode modelData
                readonly property string media: modelData.properties["media.name"] ?? ""

                Layout.fillWidth: true
                spacing: 2

                BarText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        const app = stream.modelData.properties["application.name"] || panel.label(stream.modelData);
                        return stream.media && stream.media !== app ? `${app} · ${stream.media}` : app;
                    }
                }

                VolumeRow {
                    node: stream.modelData
                }
            }
        }
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: panel.bar.fg
        opacity: 0.12
    }

    // Mute button, slider (scroll works too) and percentage
    component VolumeRow: RowLayout {
        id: row
        property PwNode node
        property bool input: false
        readonly property bool muted: node?.audio?.muted ?? false
        readonly property real volume: node?.audio ? Math.min(1, node.audio.volume) : 0

        function setVolume(v) {
            if (node?.audio)
                node.audio.volume = Math.max(0, Math.min(1, v));
        }

        Layout.fillWidth: true
        spacing: 10

        MouseArea {
            implicitWidth: 20
            implicitHeight: 20
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.node?.audio) row.node.audio.muted = !row.muted

            BarText {
                anchors.centerIn: parent
                text: row.input ? (row.muted ? "󰍭" : "󰍬") : panel.bar.volumeIcon(row.node)
                font.pixelSize: 16
                color: row.muted ? panel.bar.muted : panel.bar.fg
            }
        }

        MouseArea {
            id: track
            Layout.fillWidth: true
            implicitHeight: 20
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => row.setVolume(mouse.x / width)
            onPositionChanged: mouse => row.setVolume(mouse.x / width)
            onWheel: wheel => row.setVolume(row.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(panel.bar.fg.r, panel.bar.fg.g, panel.bar.fg.b, 0.12)

                Rectangle {
                    width: parent.width * row.volume
                    height: parent.height
                    radius: parent.radius
                    color: row.muted ? panel.bar.muted : panel.bar.accent
                }
            }

            Rectangle {
                x: (track.width - width) * row.volume
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: row.muted ? panel.bar.muted : panel.bar.fg
            }
        }

        BarText {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(row.volume * 100)}%`
            color: row.muted ? panel.bar.muted : panel.bar.fg
        }
    }

    // Devices to choose the default from, the current one highlighted
    component DeviceList: ColumnLayout {
        id: list
        property var devices: []
        property PwNode current
        signal picked(PwNode node)

        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: list.devices

            delegate: Rectangle {
                id: device
                required property PwNode modelData
                readonly property bool isCurrent: modelData === list.current

                Layout.fillWidth: true
                implicitHeight: deviceText.implicitHeight + 10
                radius: 6
                color: deviceArea.containsMouse ? panel.bar.muted : "transparent"

                BarText {
                    id: deviceText
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 10
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    elide: Text.ElideRight
                    text: panel.label(device.modelData)
                    color: device.isCurrent ? panel.bar.accent : panel.bar.fg
                    font.bold: device.isCurrent
                }

                MouseArea {
                    id: deviceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.picked(device.modelData)
                }
            }
        }
    }
}
