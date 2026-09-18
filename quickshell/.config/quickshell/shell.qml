//@ pragma UseQApplication
// UseQApplication lets tray icons open their native menus.
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    Notifications {}
}
