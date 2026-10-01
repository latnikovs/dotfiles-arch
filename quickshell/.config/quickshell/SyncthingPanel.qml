// Syncthing dropdown, from the sync icon: a pause switch, each synced folder with its state
// (click opens it), and the paired devices, connected or not, with how far they've got.
import QtQuick
import QtQuick.Layouts
import Quickshell

Dropdown {
    id: panel

    required property Syncthing syncthing
    readonly property var st: syncthing

    panelWidth: 360

    onOpenChanged: {
        st.watching = open;
        if (open)
            st.refresh();
    }

    function folderStatus(f): string {
        if (f.paused)
            return "Paused";
        if (f.errors > 0)
            return f.errors === 1 ? "1 file failed" : `${f.errors} files failed`;
        if (["syncing", "sync-preparing"].includes(f.state))
            return `Syncing · ${st.formatBytes(f.needBytes)} left`;
        if (["scanning", "scan-waiting"].includes(f.state))
            return "Scanning";
        if (f.state === "error")
            return "Stopped with an error";
        if (f.needFiles > 0)
            return `${f.needFiles} file${f.needFiles === 1 ? "" : "s"} to fetch`;
        return f.state === "idle" ? "Up to date" : "";
    }

    function deviceStatus(d): string {
        if (d.paused)
            return "Paused";
        if (!d.connected)
            return "Not connected";
        return d.completion < 100 ? `Syncing · ${Math.floor(d.completion)}%` : "Up to date";
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            BarText {
                Layout.fillWidth: true
                text: "Syncthing"
                font.bold: true
            }

            ToggleSwitch {
                visible: panel.st.devices.length > 0
                checked: !panel.st.paused
                onToggled: panel.st.setPaused(!panel.st.paused)
            }
        }

        Caption {
            text: "FOLDERS"
        }

        Repeater {
            model: panel.st.folders
            delegate: Row {
                required property var modelData
                name: modelData.label
                status: panel.folderStatus(modelData)
                alert: modelData.errors > 0 || modelData.state === "error"
                active: !modelData.paused
                clickable: true
                onClicked: {
                    panel.open = false;
                    Quickshell.execDetached(["xdg-open", modelData.path]);
                }
            }
        }

        Caption {
            text: panel.st.devices.length > 0 ? "DEVICES" : "NO PAIRED DEVICES (syncthing/setup pair)"
        }

        Repeater {
            model: panel.st.devices
            delegate: Row {
                required property var modelData
                name: modelData.name
                status: panel.deviceStatus(modelData)
                active: modelData.connected
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: panel.bar.fg
            opacity: 0.12
        }

        // Conflicts, ignore patterns, versions, adding folders: Syncthing's own web UI
        LinkText {
            text: "Web UI…"
            onClicked: {
                panel.open = false;
                panel.st.openWebUi();
            }
        }
    }

    component LinkText: BarText {
        id: link
        signal clicked

        color: linkArea.containsMouse ? panel.bar.accent : Qt.darker(panel.bar.fg, 1.4)

        MouseArea {
            id: linkArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    // Dot (accent when active), name, and its status underneath
    component Row: Rectangle {
        id: row
        property string name
        property string status
        property bool active: true
        property bool alert: false
        property bool clickable: false
        signal clicked

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + 12
        radius: 6
        color: rowArea.containsMouse ? panel.bar.muted : "transparent"

        RowLayout {
            id: rowLayout
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 10
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 10

            BarText {
                text: "●"
                font.pixelSize: 9
                color: row.alert ? panel.bar.urgent : row.active ? panel.bar.accent : panel.bar.muted
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                BarText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: row.name
                    color: row.active ? panel.bar.fg : Qt.darker(panel.bar.fg, 1.4)
                }

                Caption {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: row.status
                    color: row.alert ? panel.bar.urgent : Theme.dim
                }
            }

            BarText {
                visible: rowArea.containsMouse && row.clickable
                text: "󰉋"
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            enabled: row.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
