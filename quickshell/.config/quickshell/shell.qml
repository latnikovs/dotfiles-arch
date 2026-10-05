//@ pragma UseQApplication
//@ pragma IconTheme Nordzy-Launcher-Dark
// UseQApplication lets tray icons open their native menus. IconTheme resolves icons apps
// name (notification cards, the tray) in the launcher's Nord theme (icons/, from install.sh);
// its app icons are the same in light and dark mode.
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
            tailscale: tailscaleService
            syncthing: syncthingService
            messaging: messagingService
            updates: updatesService
            crashes: crashesService
            reminders: remindersService
            caffeine: caffeineService
            recording: recordingService
        }
    }

    Notifications {
        id: notificationService
        messaging: messagingService
    }

    Messaging {
        id: messagingService
    }

    Keyboard {
        id: keyboardService
    }

    Tailscale {
        id: tailscaleService
    }

    Syncthing {
        id: syncthingService
    }

    Updates {
        id: updatesService
    }

    Crashes {
        id: crashesService
    }

    Reminders {
        id: remindersService
        notifications: notificationService
    }

    Caffeine {
        id: caffeineService
    }

    Recording {
        id: recordingService
    }

    Polkit {}

    // Volume, microphone and brightness changes (Osd.qml); quiet while an audio dropdown is open
    Osd {
        suppressed: bars.instances.some(b => b.audioOpen)
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

        function toggleTailscale(): void {
            root.focusedBar()?.toggleTailscale();
        }

        function toggleSyncthing(): void {
            root.focusedBar()?.toggleSyncthing();
        }

        function toggleDisplay(): void {
            root.focusedBar()?.toggleDisplay();
        }

        function toggleUpdates(): void {
            root.focusedBar()?.toggleUpdates();
        }

        function toggleCrashes(): void {
            root.focusedBar()?.toggleCrashes();
        }

        function toggleReminders(): void {
            root.focusedBar()?.toggleReminders();
        }
    }
}
