// Keyboard layout (kb_layout in hyprland.lua), remembered per window: each window gets back
// the layout it had when it lost focus, and new windows start on the first layout.
// Hyprland has no per-window layouts, so this watches its events and switches with hyprctl.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: keyboard

    property var layouts: [] // xkb codes from kb_layout, e.g. ["us", "lv", "ru"]
    property int index: 0
    property string name: "" // e.g. "Latvian"
    readonly property string code: codeOf(index)

    function codeOf(i: int): string {
        return ({ us: "EN" })[layouts[i]] ?? (layouts[i] ?? "").toUpperCase();
    }

    function nameOf(i: int): string {
        return ({ us: "English", lv: "Latvian", ru: "Russian" })[layouts[i]] ?? codeOf(i);
    }

    property string activeWindow: ""
    property var windowLayouts: ({}) // window address -> layout index

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    function select(i: int): void {
        if (i !== index)
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)]);
    }

    function restore(address: string): void {
        select(windowLayouts[address] ?? 0);
    }

    // The activelayout event only names the layout, so read the index from the main keyboard.
    // A switch while this runs queues another read, so quick repeated switches aren't lost.
    property bool rereadDevices: false

    function readDevices(): void {
        if (devicesProc.running)
            rereadDevices = true;
        else
            devicesProc.running = true;
    }

    Process {
        id: devicesProc
        running: true
        command: ["hyprctl", "devices", "-j"]
        onExited: if (keyboard.rereadDevices) {
            keyboard.rereadDevices = false;
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = JSON.parse(text).keyboards.find(k => k.main);
                if (!kb)
                    return;
                keyboard.layouts = kb.layout.split(",");
                keyboard.index = kb.active_layout_index;
                keyboard.name = kb.active_keymap;
                if (keyboard.activeWindow)
                    keyboard.windowLayouts[keyboard.activeWindow] = kb.active_layout_index;
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            switch (event.name) {
            case "activelayout":
            case "configreloaded":
                keyboard.readDevices();
                break;
            case "activewindowv2":
                // Empty when focus leaves windows (e.g. to the launcher): keep the layout as is.
                // Title changes resend it for the same window, which must not undo a fresh switch.
                if (event.data && event.data !== keyboard.activeWindow) {
                    // The first window seen (focused before the shell started) keeps the current layout.
                    if (!keyboard.activeWindow)
                        keyboard.windowLayouts[event.data] = keyboard.index;
                    keyboard.activeWindow = event.data;
                    keyboard.restore(event.data);
                }
                break;
            case "closewindow":
                delete keyboard.windowLayouts[event.data];
                break;
            }
        }
    }
}
