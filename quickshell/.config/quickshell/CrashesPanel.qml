// Crashes dropdown, from the crash icon (left click): each program that crashed, latest first,
// with its signal, when and how many times. "Diagnose" hands it to Claude, × dismisses it until
// it crashes again. "Clear" (or right click on the icon) dismisses them all.
import QtQuick
import QtQuick.Layouts
import Quickshell

Dropdown {
    id: panel

    required property Crashes crashes

    panelWidth: 460

    // The icon goes away with the last one, so the dropdown does too
    Connections {
        target: panel.crashes
        function onCountChanged() {
            if (panel.crashes.count === 0)
                panel.open = false;
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            BarText {
                Layout.fillWidth: true
                text: panel.crashes.count === 1 ? "1 program crashed" : `${panel.crashes.count} programs crashed`
                font.bold: true
            }

            LinkText {
                text: "Clear"
                onClicked: {
                    panel.open = false;
                    panel.crashes.clear();
                }
            }
        }

        // Name, then signal, count and when; scrolls past a dozen or so
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 300)
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: panel.crashes.list
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
                    color: Theme.dim
                    text: modelData.signal + (modelData.count > 1 ? ` ×${modelData.count}` : "")
                }

                BarText {
                    color: Theme.dim
                    text: panel.crashes.when(modelData)
                }

                LinkText {
                    text: "Diagnose"
                    onClicked: {
                        panel.open = false;
                        panel.crashes.diagnose(modelData);
                    }
                }

                LinkText {
                    text: "󰅖"
                    onClicked: panel.crashes.dismiss(modelData.name)
                }
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
