// Nord colours for the whole shell, dark or light after the freedesktop
// color-scheme setting (scripts/theme, driven by darkman), like the GTK apps,
// kitty and fuzzel. Switches live: gsettings monitor reports each change.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    property bool dark: true

    // Light mode: Snow Storm surfaces, Polar Night text, accents dark enough to read on them
    readonly property color bg: dark ? "#2e3440" : "#eceff4"
    readonly property color surface: dark ? "#3b4252" : "#e5e9f0"
    readonly property color fg: dark ? "#d8dee9" : "#2e3440"
    readonly property color bright: dark ? "#eceff4" : "#2e3440"
    readonly property color dim: dark ? "#7b88a1" : "#646a76"
    readonly property color muted: dark ? "#4c566a" : "#aeb6c4"
    readonly property color accent: dark ? "#88c0d0" : "#5e81ac"
    readonly property color warning: dark ? "#ebcb8b" : "#ba793e"
    readonly property color urgent: dark ? "#bf616a" : "#bf616a"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    Process {
        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme; exec gsettings monitor org.gnome.desktop.interface color-scheme"]
        stdout: SplitParser {
            onRead: line => theme.dark = !line.includes("prefer-light")
        }
    }
}
