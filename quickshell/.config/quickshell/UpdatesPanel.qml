// Updates dropdown, from the update icon (left click): each pending update with the version
// it goes from and to, official packages first, then the AUR. Right click on the icon, or
// "Install" here, runs the update in a terminal.
import QtQuick
import QtQuick.Layouts
import Quickshell

Dropdown {
    id: panel

    required property Updates updates
    readonly property var official: updates.packages.filter(p => !p.aur)
    readonly property var aur: updates.packages.filter(p => p.aur)

    panelWidth: 460

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            BarText {
                Layout.fillWidth: true
                text: panel.updates.count === 1 ? "1 update" : `${panel.updates.count} updates`
                font.bold: true
            }

            LinkText {
                text: "Install"
                onClicked: {
                    panel.open = false;
                    panel.updates.install();
                }
            }
        }

        Caption {
            visible: panel.official.length > 0
            text: "OFFICIAL REPOSITORIES"
        }

        PackageList {
            packages: panel.official
        }

        Caption {
            visible: panel.aur.length > 0
            text: "AUR"
        }

        PackageList {
            packages: panel.aur
        }

        RowLayout {
            Layout.fillWidth: true

            Caption {
                Layout.fillWidth: true
                text: panel.updates.checking ? "CHECKING…"
                    : panel.updates.checked ? `CHECKED AT ${Qt.formatDateTime(panel.updates.checkedAt, "HH:mm")}` : ""
            }

            LinkText {
                visible: !panel.updates.checking
                text: "Check again"
                onClicked: panel.updates.refresh()
            }
        }
    }

    // Name on the left, "old → new" on the right; scrolls past a dozen or so
    component PackageList: ListView {
        property var packages: []

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 300)
        visible: count > 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: packages
        delegate: RowLayout {
            required property var modelData
            width: ListView.view.width
            spacing: 12

            BarText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: modelData.name
            }

            BarText {
                Layout.maximumWidth: 280
                elide: Text.ElideMiddle
                textFormat: Text.StyledText
                text: modelData.from === "" ? ""
                    : `<font color="${Theme.dim}">${modelData.from}</font> → ${modelData.to}`
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
}
