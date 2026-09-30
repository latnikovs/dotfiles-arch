// Reminders set with hypr/scripts/remind (SUPER + CTRL + R, or `remind 20m tea` in a terminal),
// kept in ~/.local/state/reminders.json. This watches that file, counts the reminders down and,
// when one is due, sends a critical notification (it stays until dismissed and gets through do
// not disturb) and drops it from the file. Any that came due while the shell wasn't running,
// say with the machine off, are sent at startup marked as missed.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: reminders

    // { id, at (epoch seconds), message } per reminder, soonest first
    property var list: []
    readonly property int count: list.length
    readonly property var next: list.length > 0 ? list[0] : null
    property real now: Date.now() / 1000
    readonly property real startedAt: Date.now() / 1000

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/remind"
    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/reminders.json"

    // Ids already notified, so a due one fires once while the script takes it out of the file
    property var fired: ({})

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

    function fire(r): void {
        fired[r.id] = true;
        const missed = r.at < startedAt - 60;
        const body = missed ? `Missed, was due ${when(r)}` : Qt.formatDateTime(new Date(r.at * 1000), "HH:mm");
        Quickshell.execDetached(["notify-send", "-a", "Reminders", "-u", "critical", "--", r.message, body]);
        cancel(r.id);
    }

    function check(): void {
        now = Date.now() / 1000;
        for (const r of list) {
            if (r.at <= now && !fired[r.id])
                fire(r);
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
                    reminders.list = parsed.filter(r => r && r.id && typeof r.at === "number").sort((a, b) => a.at - b.at);
                    reminders.check();
                }
            } catch (e) {}
        }
    }

    // Wall clock rather than one long timer, so it stays right across suspend
    Timer {
        interval: 1000
        running: reminders.count > 0
        repeat: true
        onTriggered: reminders.check()
    }
}
