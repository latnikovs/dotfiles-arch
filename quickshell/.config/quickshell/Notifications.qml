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
    readonly property int gap: 6

    // Minimum time on screen in ms; critical stays until dismissed. A longer
    // expire_timeout from the sender is honoured up to maxLife.
    readonly property int lowLife: 5000
    readonly property int normalLife: 8000
    readonly property int maxLife: 30000

    property bool dnd: false
    // Marks new mail, Teams and WhatsApp messages, and brings their app up when a notification is clicked
    required property Messaging messaging

    // History: the last 30 notifications that left the screen (expired or dismissed) or
    // arrived while silenced, newest first. Saved to `historyFile`, so it survives restarts.
    readonly property int historyLimit: 30
    property var history: []
    property int historySeq: 0
    property bool historyOpen: false
    // Message previews end up on disk, so the file sits in a directory only this user can open
    readonly property string historyDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    readonly property string historyFile: historyDir + "/notifications.json"
    property bool historyLoaded: false // nothing is written before the saved list is read

    onHistoryChanged: {
        if (historyLoaded)
            historyView.setText(JSON.stringify(history.map(e => Object.assign({}, e, { time: e.time.getTime() }))) + "\n");
    }

    // Copied while the notification is live: Quickshell clears its fields by the time `closed` fires
    function snapshot(n) {
        return {
            keep: !n.transient && n.appName !== "notifications", // sender asked not to keep it, or our own status toast
            appName: n.appName,
            summary: n.summary,
            body: n.body,
            // Image data sent with the notification is served from memory and dies with it;
            // image://icon/ (files and theme icons) keeps working
            image: n.image.startsWith("image://") && !n.image.startsWith("image://icon/") ? "" : n.image,
            appIcon: n.appIcon,
            urgency: n.urgency
        };
    }

    function remember(entry) {
        if (!entry.keep)
            return;
        history = [Object.assign({ key: ++historySeq, time: new Date() }, entry), ...history].slice(0, historyLimit);
    }

    function forget(key) {
        history = history.filter(e => e.key !== key);
    }

    // Countdown state lives here, keyed by notification id, because the
    // Repeater recreates cards whenever the list changes.
    property var remaining: ({})
    property int hoveredId: -1
    property int tick: 0 // bumped by the countdown so bindings re-read `remaining`

    // Cards slide down out from under the bar and back up when they go, as in Omarchy. Kept here
    // by id for the same reason: `entered` cards don't slide in again when the Repeater rebuilds,
    // and `leaving` ones are sliding away before their notification is closed.
    property var entered: ({})
    property var leaving: ({})
    property var pendingCloses: []
    readonly property int slideMs: 150

    // Slides the card away, then closes the notification with `close`
    function leave(n, close) {
        if (leaving[n.id])
            return;
        leaving[n.id] = true;
        pendingCloses = [...pendingCloses, close];
        tick++;
        if (!closeTimer.running)
            closeTimer.start();
    }

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
        leave(n, () => n.dismiss());
    }

    Timer {
        id: closeTimer
        interval: root.slideMs
        onTriggered: {
            const closes = root.pendingCloses;
            root.pendingCloses = [];
            for (const close of closes)
                close();
        }
    }

    // Left click runs the sender's default action (e.g. focus the chat), otherwise just closes.
    // Mail, Teams and WhatsApp live on hidden special workspaces, which that can't bring up by itself.
    function activate(n) {
        messaging.reveal(n);
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default") {
                n.actions[i].invoke();
                return;
            }
        }
        dismiss(n);
    }

    // A button on the card (NotificationCard.qml): runs that action, which closes the notification
    // unless the sender marked it resident
    function invoke(n, identifier) {
        const action = n.actions.find(a => a.identifier === identifier);
        if (!action)
            return;
        delete remaining[n.id];
        action.invoke();
    }

    // The directory has to exist (and be private) before the file is read or written
    Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", root.historyDir]
        onExited: historyView.path = root.historyFile
    }

    FileView {
        id: historyView
        printErrors: false
        // Notifications that arrived while the file was loading stay on top
        function restore(saved) {
            const entries = saved.filter(e => e && typeof e.key === "number" && typeof e.time === "number").map(e => Object.assign({}, e, { time: new Date(e.time) }));
            root.historySeq = Math.max(root.historySeq, ...entries.map(e => e.key));
            const fresh = root.history.map(e => Object.assign({}, e, { key: ++root.historySeq }));
            root.historyLoaded = true;
            root.history = [...fresh, ...entries].slice(0, root.historyLimit);
        }
        onLoaded: {
            let saved = [];
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed))
                    saved = parsed;
            } catch (e) {}
            restore(saved);
        }
        onLoadFailed: restore([]) // first run: no file yet
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: n => {
            // Silenced notifications are dropped, except critical ones and our own status toasts
            let entry = root.snapshot(n);
            root.messaging.noticed(n);
            const id = n.id;
            n.closed.connect(() => {
                delete root.entered[id];
                delete root.leaving[id];
            });
            if (root.dnd && n.urgency !== NotificationUrgency.Critical && n.appName !== "notifications") {
                root.remember(entry);
                return;
            }
            n.tracked = true;
            // Kept even when the app withdraws it (CloseRequested): web apps like Teams
            // close their own notifications seconds after showing them
            n.closed.connect(() => root.remember(entry));
            root.restart(n);
            // A sender updating the notification in place (replaces_id) gets a fresh countdown
            const updated = () => {
                entry = root.snapshot(n);
                root.restart(n);
            };
            n.summaryChanged.connect(updated);
            n.bodyChanged.connect(updated);
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            for (const n of root.popups) {
                if (root.lifetime(n) === 0 || n.id === root.hoveredId || root.leaving[n.id])
                    continue;
                if (!(n.id in root.remaining)) {
                    root.restart(n); // survived a config reload
                    continue;
                }
                root.remaining[n.id] -= interval;
                if (root.remaining[n.id] <= 0) {
                    delete root.remaining[n.id];
                    root.leave(n, () => n.expire());
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

        // With the history open, clears it instead (SUPER + SHIFT + comma)
        function dismissAll(): string {
            if (root.historyOpen) {
                root.history = [];
                return "cleared";
            }
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

        function toggleHistory(): string {
            root.historyOpen = !root.historyOpen;
            return root.historyOpen ? "open" : "closed";
        }

        function listHistory(): string {
            return JSON.stringify(root.history);
        }

        function clearHistory(): string {
            root.history = [];
            return "ok";
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

        // Starts at the bar's bottom edge, so cards slide out from under the bar
        Item {
            anchors {
                fill: parent
                topMargin: root.topMargin - root.gap
            }
            clip: true

            ColumnLayout {
                id: column
                anchors {
                    top: parent.top
                    right: parent.right
                    rightMargin: root.sideMargin
                }
                spacing: 0

                Repeater {
                    model: root.popups

                    // Holds the card and the gap above it; both shrink to nothing as the card slides up
                    delegate: Item {
                        id: slot
                        required property Notification modelData
                        readonly property bool leaving: {
                            root.tick;
                            return root.leaving[modelData.id] === true;
                        }
                        property real reveal: 0 // 0 under the bar, 1 in place
                        property bool ready: false

                        Behavior on reveal {
                            enabled: slot.ready
                            NumberAnimation {
                                duration: slot.leaving ? root.slideMs : 200
                                easing.type: slot.leaving ? Easing.InCubic : Easing.OutCubic
                            }
                        }

                        Component.onCompleted: {
                            reveal = root.entered[modelData.id] && !leaving ? 1 : 0;
                            ready = true;
                            reveal = Qt.binding(() => slot.leaving ? 0 : 1);
                            root.entered[modelData.id] = true;
                        }

                        implicitWidth: card.implicitWidth
                        implicitHeight: (card.implicitHeight + root.gap) * reveal
                        // A card leaving from the middle slides up behind the ones above it
                        z: leaving ? -1 : 0

                        NotificationCard {
                            id: card
                            y: slot.height - height
                            width: implicitWidth
                            height: implicitHeight
                            appName: slot.modelData.appName
                            summary: slot.modelData.summary
                            body: slot.modelData.body
                            image: slot.modelData.image
                            appIcon: root.messaging.iconOf(slot.modelData)
                            urgency: slot.modelData.urgency
                            actions: slot.modelData.actions
                            progress: {
                                root.tick;
                                return root.progress(slot.modelData);
                            }
                            onHoveredChanged: {
                                if (hovered)
                                    root.hoveredId = slot.modelData.id;
                                else if (root.hoveredId === slot.modelData.id)
                                    root.hoveredId = -1;
                            }
                            onActivated: root.activate(slot.modelData)
                            onCloseRequested: root.dismiss(slot.modelData)
                            onActionInvoked: identifier => root.invoke(slot.modelData, identifier)
                        }
                    }
                }
            }
        }
    }
}
