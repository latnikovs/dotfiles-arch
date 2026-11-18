// Pending package updates for the bar, from hypr/scripts/updates (official packages via
// checkupdates, AUR ones via yay). Checked a minute after login and then every 6 hours,
// as in Omarchy; `quickshell ipc call updates refresh` checks at once, which
// `updates run` does after updating.
//
// Also what runs for an update in the background, for the bar's spinner: the health check
// (scripts/healthcheck) and Claude's review (scripts/update-review, its state from the
// Claude Code hooks in tmux/.tmux/scripts/claude-state.sh). They report themselves with
// `quickshell ipc call updates task <name> <pid> <state>` (an empty state when done); one
// whose PID is gone is dropped, in case it ended without saying so.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: updates

    // { name, from, to, aur } per pending update, official packages first
    property var packages: []
    readonly property int count: packages.length
    readonly property int aurCount: packages.filter(p => p.aur).length
    readonly property bool checking: check.running
    property date checkedAt
    property bool checked: false

    // When a system upgrade (pacman/yay -Syu, from `updates run` or by hand) last started,
    // from pacman's log; null if it has none. `now` ticks hourly so "3d ago" stays current.
    property var lastRun: null
    property date now: new Date()
    readonly property string lastRunAgo: {
        if (!lastRun)
            return "";
        const hours = Math.floor((now - lastRun) / 3600000);
        return hours < 1 ? "just now" : hours < 24 ? `${hours}h ago` : `${Math.floor(hours / 24)}d ago`;
    }

    // name ("check", "review") -> { pid, state }; state "busy", or "waiting" (Claude waits for you)
    property var tasks: ({})
    readonly property bool active: Object.keys(tasks).length > 0
    readonly property var check: tasks.check ?? null
    readonly property var review: tasks.review ?? null

    function setTask(name: string, pid: int, state: string): void {
        const next = Object.assign({}, tasks);
        if (state === "")
            delete next[name];
        else
            next[name] = { pid, state };
        tasks = next;
    }

    // The review's terminal, brought forward
    function showReview(): void {
        if (review)
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ window = "pid:${review.pid}" })`]);
    }

    function refresh(): void {
        if (!check.running)
            check.running = true;
        lastRunCheck.running = true;
    }

    // In a terminal of its own, tiled like any other window
    function install(): void {
        Quickshell.execDetached(["sh", "-c", "exec ${DOTFILES_TERMINAL:-kitty} --class org.dotfiles.updates ~/.config/hypr/scripts/updates run"]);
    }

    Process {
        id: check
        // "ok" last only when the check worked, so a failed one (offline) keeps the old list
        command: ["sh", "-c", "list=$(~/.config/hypr/scripts/updates list) && printf '%s\\nok\\n' \"$list\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim() !== "");
                if (lines.pop() !== "ok")
                    return;
                // "name old -> new", with " (AUR)" after the AUR ones
                updates.packages = lines.map(l => {
                    const m = /^(\S+) (\S+) -> (\S+)( \(AUR\))?$/.exec(l.trim());
                    return m ? { name: m[1], from: m[2], to: m[3], aur: !!m[4] } : { name: l.trim(), from: "", to: "", aur: false };
                });
                updates.checkedAt = new Date();
                updates.checked = true;
            }
        }
    }

    Timer {
        interval: 60 * 1000
        running: true
        onTriggered: updates.refresh()
    }

    // "[2026-11-18T18:43:03+0200] [PACMAN] starting full system upgrade" -> its timestamp
    Process {
        id: lastRunCheck
        running: true
        command: ["sh", "-c", "grep -F '[PACMAN] starting full system upgrade' /var/log/pacman.log | tail -n1 | cut -d']' -f1 | tr -d '['"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Date() wants "+02:00", pacman writes "+0200"
                const stamp = text.trim().replace(/([+-]\d\d)(\d\d)$/, "$1:$2");
                const date = new Date(stamp);
                updates.lastRun = isNaN(date) ? null : date;
                updates.now = new Date();
            }
        }
    }

    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: updates.now = new Date()
    }

    Timer {
        interval: 6 * 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: updates.refresh()
    }

    // Drops tasks whose process is gone
    Process {
        id: alive
        command: ["sh", "-c", "for p; do kill -0 \"$p\" 2>/dev/null && echo \"$p\"; done", "sh"]
            .concat(Object.values(updates.tasks).map(t => String(t.pid)))
        stdout: StdioCollector {
            onStreamFinished: {
                const living = text.split("\n").filter(l => l !== "");
                for (const [name, task] of Object.entries(updates.tasks))
                    if (!living.includes(String(task.pid)))
                        updates.setTask(name, 0, "");
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: updates.active
        onTriggered: alive.running = true
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            updates.refresh();
        }

        function task(name: string, pid: int, state: string): void {
            updates.setTask(name, pid, state);
        }
    }
}
