// Programs of this user's that crashed (dumped core), for the bar icon in place of notifications
// (as Omarchy's crash watcher, but kept until dealt with). Follows systemd-coredump's journal
// entries; ~/.local/state/crashes.json only holds what was cleared (all up to a time, or one
// program up to its last crash), so crashes from before a reboot, or of the shell itself,
// show up once it's back. hypr/scripts/crash-diagnose hands one to Claude.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: crashes

    // Program names never worth listing, e.g. ["steam"]
    readonly property var ignore: []

    // systemd-coredump logs every core dump under this MESSAGE_ID (systemd.journal-fields(7))
    readonly property string messageId: "fc2e22bc6ee647b6b90729ab34a250b1"
    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/crashes.json"

    // Cleared: everything up to `cleared`, and each program in `dismissed` up to its time (epoch seconds)
    property real cleared: 0
    property var dismissed: ({})
    // { time, pid, name, exe, signal } per crash from the journal, oldest first
    property var entries: []
    // One per program, latest first: { name, exe, pid, signal, time, count }
    readonly property var list: {
        const byName = {};
        for (const e of entries) {
            if (e.time <= Math.max(cleared, dismissed[e.name] ?? 0))
                continue;
            const c = byName[e.name];
            byName[e.name] = { name: e.name, exe: e.exe, pid: e.pid, signal: e.signal, time: e.time, count: c ? c.count + 1 : 1 };
        }
        return Object.values(byName).sort((a, b) => b.time - a.time);
    }
    readonly property int count: list.length

    function dismiss(name): void {
        const c = list.find(c => c.name === name);
        if (!c)
            return;
        const d = Object.assign({}, dismissed);
        d[name] = c.time;
        dismissed = d;
        save();
    }

    function clear(): void {
        if (count === 0)
            return;
        cleared = list[0].time;
        dismissed = {};
        save();
    }

    // Claude in a terminal, with the diagnose-crash skill (claude/.claude/skills)
    function diagnose(c): void {
        Quickshell.execDetached(["sh", "-c", 'exec ~/.config/hypr/scripts/crash-diagnose "$@"', "sh",
            String(c.pid), c.name, c.exe, c.signal, when(c)]);
    }

    // "14:05" today, "Mon 14:05" within the week, else "29 Sep 14:05"
    function when(c): string {
        const d = new Date(c.time * 1000);
        const days = (Date.now() - d.getTime()) / 86400000;
        const today = d.toDateString() === new Date().toDateString();
        return Qt.formatDateTime(d, today ? "HH:mm" : days < 6 ? "ddd HH:mm" : "d MMM HH:mm");
    }

    function save(): void {
        const d = {};
        for (const [name, time] of Object.entries(dismissed)) {
            if (time > cleared)
                d[name] = time;
        }
        view.setText(JSON.stringify({ cleared, dismissed: d }) + "\n");
    }

    // Journal fields that aren't valid UTF-8 come as byte arrays
    function field(v): string {
        if (Array.isArray(v))
            return String.fromCharCode(...v);
        return v === undefined || v === null ? "" : String(v);
    }

    function add(line): void {
        let j;
        try {
            j = JSON.parse(line);
        } catch (e) {
            return;
        }
        const exe = field(j.COREDUMP_EXE);
        // comm is cut to 15 characters, so the executable's name where there is one
        const name = exe.startsWith("/") ? exe.slice(exe.lastIndexOf("/") + 1) : field(j.COREDUMP_COMM) || "unknown";
        const pid = parseInt(field(j.COREDUMP_PID));
        if (isNaN(pid) || ignore.includes(name))
            return;
        entries = entries.concat([{
            time: parseInt(field(j.__REALTIME_TIMESTAMP)) / 1e6,
            pid,
            name,
            exe,
            signal: field(j.COREDUMP_SIGNAL_NAME) || "signal " + field(j.COREDUMP_SIGNAL)
        }]);
    }

    // The file's directory has to exist before it's read or written
    Process {
        running: true
        command: ["mkdir", "-p", crashes.file.slice(0, crashes.file.lastIndexOf("/"))]
        onExited: view.path = crashes.file
    }

    FileView {
        id: view
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                crashes.cleared = Number(s.cleared) || 0;
                crashes.dismissed = s.dismissed && typeof s.dismissed === "object" ? s.dismissed : {};
            } catch (e) {}
            journal.start();
        }
        // First run: nothing cleared yet, so the last day's crashes
        onLoadFailed: {
            crashes.cleared = Date.now() / 1000 - 86400;
            journal.start();
        }
    }

    // Everything since the last clear, then new ones as they come. Only this user's: a daemon
    // dumping core is the system's business.
    Process {
        id: journal

        function start(): void {
            if (running)
                return;
            crashes.entries = [];
            command = ["sh", "-c", 'exec journalctl --follow --lines=all --output=json --no-pager --since="@$1" MESSAGE_ID="$2" COREDUMP_UID="$(id -u)"',
                "sh", String(Math.floor(crashes.cleared)), crashes.messageId];
            running = true;
        }

        stdout: SplitParser {
            onRead: line => crashes.add(line)
        }
        // journalctl shouldn't exit; if it does, read it all again in a bit
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: journal.start()
    }
}
