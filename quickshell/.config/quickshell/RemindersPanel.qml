// Reminders, dropping down from the reminder countdown (left click) and a control center page: each one with when it's due and the
// time left, soonest first, × to cancel it. "New" asks for another (as does right click on the icon).
import QtQuick
import QtQuick.Layouts
import Quickshell

Page {
    id: panel

    required property Reminders reminders


    // The countdown goes away with the last one, so this does too
    Connections {
        target: panel.reminders
        function onCountChanged() {
            if (panel.reminders.count === 0)
                panel.close();
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
                text: panel.reminders.count === 1 ? "1 reminder" : `${panel.reminders.count} reminders`
                font.bold: true
            }

            LinkText {
                text: "Clear"
                onClicked: {
                    panel.close();
                    panel.reminders.clear();
                }
            }

            LinkText {
                text: "New"
                onClicked: {
                    panel.close();
                    panel.reminders.prompt();
                }
            }
        }

        // Message on the left, then when and the time left; scrolls past a dozen or so
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 300)
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: panel.reminders.list
            delegate: RowLayout {
                required property var modelData
                width: ListView.view.width
                spacing: 12

                BarText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: modelData.message
                }

                BarText {
                    color: Theme.dim
                    text: panel.reminders.when(modelData)
                }

                BarText {
                    Layout.minimumWidth: 52
                    horizontalAlignment: Text.AlignRight
                    text: panel.reminders.left(modelData)
                }

                LinkText {
                    text: "󰅖"
                    onClicked: panel.reminders.cancel(modelData.id)
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
