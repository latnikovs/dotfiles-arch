// Whether a screen recording (scripts/screenrecord, gpu-screen-recorder) is running, for the
// bar's red dot. The script calls `quickshell ipc call recording refresh` as it starts and
// stops; while on, a slow check also catches a recorder that died by itself.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool on: false

    function refresh() {
        check.running = true;
    }

    function stop() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/screenrecord", "stop"]);
    }

    Process {
        id: check
        command: ["pgrep", "-f", "^gpu-screen-recorder"]
        running: true
        onExited: code => root.on = code === 0
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.on
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "recording"

        function refresh(): void {
            root.refresh();
        }
    }
}
