// Reminders set with hypr/scripts/remind (SUPER + CTRL + R, or `remind 20m tea` in a terminal),
// kept in ~/.local/state/reminders.json. This watches that file, counts the reminders down and,
// when one is due, has the script send a critical notification (it stays until dismissed and
// gets through do not disturb) with snooze buttons. The reminder stays in the file, marked fired,
// until that notification is dismissed or snoozed. At startup, any that came due while the shell
// wasn't running (say with the machine off), and fired ones whose notification is gone, are sent
// again marked as missed.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: reminders

    required property Notifications notifications

    // { id, at (epoch seconds), message } per reminder still to come, soonest first
    property var list: []
    // Fired ones waiting for their notification to be dismissed or snoozed
    property var waiting: []
    readonly property int count: list.length
    readonly property var next: list.length > 0 ? list[0] : null
    property real now: Date.now() / 1000
    readonly property real startedAt: Date.now() / 1000

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/remind"
    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/reminders.json"

    // Ids already sent, so each goes out once while the script marks it fired in the file
    property var sent: ({})

    // Asks for a new one in fuzzel
    function prompt(): void {
        Quickshell.execDetached([script]);
    }

    function cancel(id): void {
        Quickshell.execDetached([script, "cancel", id]);
    }

    function clear(): void {
        Quickshell.execDetached([script, "clear"]);
    }

    // "45s", "12m", "2h 5m", "3d 4h"
    function left(r): string {
        const s = Math.max(0, Math.round(r.at - now));
        if (s < 60)
            return `${s}s`;
        const m = Math.ceil(s / 60);
        if (m < 60)
            return `${m}m`;
        if (m < 24 * 60)
            return m % 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m / 60}h`;
        const h = Math.round(m / 60);
        return h % 24 ? `${Math.floor(h / 24)}d ${h % 24}h` : `${h / 24}d`;
    }

    // "15:20", or "Thu 1 Oct 09:00" when it isn't today
    function when(r): string {
        const d = new Date(r.at * 1000);
        const today = new Date(now * 1000).toDateString() === d.toDateString();
        return Qt.formatDateTime(d, today ? "HH:mm" : "ddd d MMM HH:mm");
    }

    function fire(r, missed): void {
        sent[r.id] = true;
        Quickshell.execDetached([script, "fire", r.id, missed ? "missed" : ""]);
    }

    function check(): void {
        now = Date.now() / 1000;
        for (const r of list) {
            if (r.at <= now && !sent[r.id])
                fire(r, r.at < startedAt - 60);
        }
    }

    // Fired ones with no notification up: left unanswered at shutdown, or the shell was restarted.
    // Not on a config reload, which keeps the notifications.
    function resend(): void {
        const up = notifications.popups.map(n => n.hints["x-dotfiles-reminder"]);
        for (const r of waiting) {
            if (!sent[r.id] && !up.includes(r.id))
                fire(r, true);
        }
    }

    // The file has to exist before it's watched; the script only writes it on the first reminder
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "${1%/*}" && { [ -s "$1" ] || echo "[]" >"$1"; }', "sh", reminders.file]
        onExited: view.path = reminders.file
    }

    FileView {
        id: view
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // Half-written or hand-edited badly: keep the last good list until the next change
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed)) {
                    const valid = parsed.filter(r => r && r.id && typeof r.at === "number").sort((a, b) => a.at - b.at);
                    reminders.list = valid.filter(r => !r.fired);
                    reminders.waiting = valid.filter(r => r.fired);
                    reminders.check();
                }
            } catch (e) {}
        }
    }

    // Once at startup, after the notification server has taken back what it had before a reload
    Timer {
        interval: 3000
        running: true
        onTriggered: reminders.resend()
    }

    // Wall clock rather than one long timer, so it stays right across suspend
    Timer {
        interval: 1000
        running: reminders.count > 0
        repeat: true
        onTriggered: reminders.check()
    }
}
