// Notification daemon: toast cards stacked in the top-right corner, newest on top.
// Control it with `quickshell ipc call notifications <function>` (see IpcHandler below).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    // Below the bar (Bar.qml, height 26) with Hyprland's gaps_out (6)
    readonly property int topMargin: 26 + 6
    readonly property int sideMargin: 6

    // Minimum time on screen in ms; critical stays until dismissed. A longer
    // expire_timeout from the sender is honoured up to maxLife.
    readonly property int lowLife: 5000
    readonly property int normalLife: 8000
    readonly property int maxLife: 30000

    property bool dnd: false

    // Countdown state lives here, keyed by notification id, because the
    // Repeater recreates cards whenever the list changes.
    property var remaining: ({})
    property int hoveredId: -1
    property int tick: 0 // bumped by the countdown so bindings re-read `remaining`

    readonly property var popups: server.trackedNotifications.values.slice().reverse()

    // 0 means sticky
    function lifetime(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        const min = n.urgency === NotificationUrgency.Low ? lowLife : normalLife;
        return Math.min(maxLife, Math.max(min, n.expireTimeout));
    }

    function restart(n) {
        remaining[n.id] = lifetime(n);
        tick++;
    }

    function progress(n) {
        const life = lifetime(n);
        return life > 0 ? (remaining[n.id] ?? life) / life : 0;
    }

    function dismiss(n) {
        delete remaining[n.id];
        n.dismiss();
    }

    // Left click runs the sender's default action (e.g. focus the chat), otherwise just closes.
    function activate(n) {
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default") {
                n.actions[i].invoke();
                return;
            }
        }
        dismiss(n);
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: n => {
            // Silenced notifications are dropped, except critical ones and our own status toasts
            if (root.dnd && n.urgency !== NotificationUrgency.Critical && n.appName !== "notifications")
                return;
            n.tracked = true;
            root.restart(n);
            // A sender updating the notification in place (replaces_id) gets a fresh countdown
            n.summaryChanged.connect(() => root.restart(n));
            n.bodyChanged.connect(() => root.restart(n));
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            for (const n of root.popups) {
                if (root.lifetime(n) === 0 || n.id === root.hoveredId)
                    continue;
                if (!(n.id in root.remaining)) {
                    root.restart(n); // survived a config reload
                    continue;
                }
                root.remaining[n.id] -= interval;
                if (root.remaining[n.id] <= 0) {
                    delete root.remaining[n.id];
                    n.expire();
                }
            }
            root.tick++;
        }
    }

    IpcHandler {
        target: "notifications"

        function dismissOne(): string {
            if (root.popups.length === 0)
                return "none";
            root.dismiss(root.popups[0]);
            return "ok";
        }

        function dismissAll(): string {
            for (const n of root.popups)
                root.dismiss(n);
            return "ok";
        }

        function invokeLast(): string {
            if (root.popups.length === 0)
                return "none";
            root.activate(root.popups[0]);
            return "ok";
        }

        function toggleDnd(): string {
            root.dnd = !root.dnd;
            return root.dnd ? "on" : "off";
        }
    }

    // Full-screen and click-through except over the cards: resizing the surface
    // with every toast makes the compositor briefly stretch the old buffer.
    PanelWindow {
        visible: root.popups.length > 0
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {
            item: column
        }

        ColumnLayout {
            id: column
            anchors {
                top: parent.top
                right: parent.right
                topMargin: root.topMargin
                rightMargin: root.sideMargin
            }
            spacing: 6

            Repeater {
                model: root.popups

                delegate: NotificationCard {
                    required property Notification modelData
                    notification: modelData
                    progress: {
                        root.tick;
                        return root.progress(modelData);
                    }
                    onHoveredChanged: {
                        if (hovered)
                            root.hoveredId = modelData.id;
                        else if (root.hoveredId === modelData.id)
                            root.hoveredId = -1;
                    }
                    onActivated: root.activate(modelData)
                    onCloseRequested: root.dismiss(modelData)
                }
            }
        }
    }
}
