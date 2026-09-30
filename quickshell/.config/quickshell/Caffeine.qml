// Caffeine, like macOS caffeinate: holds a systemd idle inhibitor, which hypridle honours, so the
// screen neither locks nor blanks while it's on. Suspending by hand still works.
// Toggle with `quickshell ipc call caffeine toggle`; it starts off, also after a quickshell restart.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool on: false

    // Stopping it SIGTERMs systemd-inhibit, which releases the lock and ends the sleep
    Process {
        running: root.on
        command: ["systemd-inhibit", "--what=idle", "--who=Caffeine", "--why=Caffeine is on", "sleep", "infinity"]
    }

    IpcHandler {
        target: "caffeine"

        function toggle(): string {
            root.on = !root.on;
            return root.on ? "on" : "off";
        }
    }
}
