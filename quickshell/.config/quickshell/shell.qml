//@ pragma UseQApplication
// UseQApplication lets tray icons open their native menus.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    function focusedBar() {
        return bars.instances.find(b => b.screen.name === Hyprland.focusedMonitor?.name) ?? bars.instances[0];
    }

    Variants {
        id: bars
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
            notifications: notificationService
            keyboard: keyboardService
        }
    }

    Notifications {
        id: notificationService
    }

    Keyboard {
        id: keyboardService
    }

    // Bar dropdowns on the focused monitor: `quickshell ipc call bar <function>`
    IpcHandler {
        target: "bar"

        function toggleCalendar(): void {
            root.focusedBar()?.toggleCalendar();
        }

        function toggleWeather(): void {
            root.focusedBar()?.toggleWeather();
        }

        function toggleAudio(): void {
            root.focusedBar()?.toggleAudio();
        }

        function toggleNetwork(): void {
            root.focusedBar()?.toggleNetwork();
        }

        function toggleBluetooth(): void {
            root.focusedBar()?.toggleBluetooth();
        }
    }
}
