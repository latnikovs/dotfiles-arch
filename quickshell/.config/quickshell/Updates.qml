// Pending package updates for the bar, from hypr/scripts/updates (official packages via
// checkupdates, AUR ones via yay). Checked a minute after login and then every 6 hours,
// as in Omarchy; `quickshell ipc call updates refresh` checks at once, which
// `updates run` does after updating.
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

    function refresh(): void {
        if (!check.running)
            check.running = true;
    }

    // In a floating terminal (the float-updates rule in hyprland.lua)
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

    Timer {
        interval: 6 * 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: updates.refresh()
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            updates.refresh();
        }
    }
}
