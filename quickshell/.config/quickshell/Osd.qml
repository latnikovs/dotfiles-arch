// On-screen display, after Omarchy's (swayosd): a small card near the bottom of the focused
// monitor whenever the output volume or mute changes (keys, the bar, any app), the microphone
// is muted or unmuted, or the brightness keys report a new level through
// `quickshell ipc call osd brightness <percent>`. Click-through; gone after 1.5 s.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Scope {
    id: root

    // While the bar's audio dropdown is open its sliders already show the level
    property bool suppressed: false

    property string icon: ""
    property string label: ""
    property real value: -1 // 0–1 draws a level bar; below 0 shows the label instead
    property bool dimmed: false
    property bool shown: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Nodes report their volume once bound, at startup and after a default device switch;
    // those first values aren't changes, so the card waits a moment before reacting
    property bool armed: false
    onSinkChanged: rearm()
    onSourceChanged: rearm()

    function rearm() {
        armed = false;
        armTimer.restart();
    }

    function show(icon, label, value, dimmed) {
        if (suppressed)
            return;
        root.icon = icon;
        root.label = label;
        root.value = value;
        root.dimmed = dimmed;
        shown = true;
        hideTimer.restart();
    }

    function showVolume() {
        const audio = sink?.audio;
        if (!armed || !audio)
            return;
        const v = Math.min(1, audio.volume);
        const icon = audio.muted ? "󰝟" : v >= 0.67 ? "󰕾" : v >= 0.34 ? "󰖀" : "󰕿";
        show(icon, "", v, audio.muted);
    }

    function showMicrophone() {
        const audio = source?.audio;
        if (!armed || !audio)
            return;
        show(audio.muted ? "󰍭" : "󰍬", audio.muted ? "Microphone muted" : "Microphone on", -1, audio.muted);
    }

    Timer {
        id: armTimer
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    // Volume and mute are only valid on bound nodes
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() {
            root.showVolume();
        }
        function onMutedChanged() {
            root.showVolume();
        }
    }

    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() {
            root.showMicrophone();
        }
    }

    IpcHandler {
        target: "osd"

        function brightness(percent: int): void {
            root.show("󰃠", "", Math.max(0, Math.min(100, percent)) / 100, false);
        }
    }

    PanelWindow {
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.bottom: true
        margins.bottom: 120
        implicitWidth: 260
        implicitHeight: 48
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        // Empty: clicks go to the window underneath
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.bg
            border.width: 2
            border.color: Theme.accent

            Row {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 12

                Text {
                    id: iconText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    text: root.icon
                    color: root.dimmed ? Theme.dim : Theme.bright
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                }

                // The level: a track with the filled part, then the percentage
                Rectangle {
                    visible: root.value >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - iconText.width - percentText.width - 2 * parent.spacing
                    height: 6
                    radius: 3
                    color: Theme.muted

                    Rectangle {
                        width: parent.width * Math.max(0, root.value)
                        height: parent.height
                        radius: parent.radius
                        color: root.dimmed ? Theme.dim : Theme.accent
                    }
                }

                Text {
                    id: percentText
                    visible: root.value >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    text: `${Math.round(root.value * 100)}`
                    color: root.dimmed ? Theme.dim : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    visible: root.value < 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }
        }
    }
}
