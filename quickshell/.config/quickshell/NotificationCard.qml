// One notification card, used for toasts and history entries. Presentational only:
// Notifications.qml drives the countdown and actions.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card

    property string appName: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property string appIcon: ""
    property int urgency: NotificationUrgency.Normal
    property string time: "" // shown next to the app name in history
    property real progress: 0 // 1 → 0 as the toast times out; 0 hides the bar
    // The sender's actions ({ identifier, text }); all but "default" (the card's own click) get a button
    property var actions: []
    readonly property var buttons: actions.filter(a => a.identifier !== "default" && a.text !== "")
    readonly property alias hovered: hover.hovered

    signal activated
    signal closeRequested
    signal actionInvoked(string identifier)

    // Nord, light or dark (Theme.qml), matching the bar, fuzzel and Hyprland borders
    readonly property color fg: Theme.bright
    readonly property color bodyColor: Theme.fg
    readonly property color dim: Theme.dim
    readonly property color accent: Theme.accent
    readonly property color urgent: Theme.urgent
    readonly property string fontFamily: Theme.fontFamily

    readonly property bool critical: urgency === NotificationUrgency.Critical
    // Chromium starts a web notification's body with the site, "teams.microsoft.com\n\n…"
    // (as a link when the server takes hyperlinks). Show the site in the header instead.
    readonly property var webOrigin: /^(?:<a [^>]*>)?([\w-]+(?:\.[\w-]+)+(?::\d+)?)(?:<\/a>)?\n\n/.exec(body)
    readonly property string sender: webOrigin ? webOrigin[1].replace(/^www\./, "") : appName
    readonly property string bodyText: webOrigin ? body.slice(webOrigin[0].length) : body
    readonly property string iconSource: source(image) || source(appIcon)

    // Accepts a file path, a URL, or an icon theme name ("" when the theme lacks it)
    function source(s) {
        if (!s)
            return "";
        if (s.startsWith("/"))
            return "file://" + s;
        if (s.includes("://"))
            return s;
        return Quickshell.iconPath(s, true);
    }

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 24
    radius: 10
    color: Theme.bg
    border.width: 2
    border.color: critical ? urgent : accent

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? card.closeRequested() : card.activated()
    }

    RowLayout {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 12
        }
        spacing: 12

        Image {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop
            visible: card.iconSource !== "" && status !== Image.Error
            source: card.iconSource
            sourceSize.width: 80
            sourceSize.height: 80
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.rightMargin: 14 // keep clear of the close button
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                visible: appNameText.visible || card.time !== ""

                Text {
                    id: appNameText
                    Layout.fillWidth: true
                    visible: text !== "" && text !== card.summary
                    text: card.sender
                    textFormat: Text.PlainText
                    color: card.dim
                    font.family: card.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                    visible: !appNameText.visible // keeps the time right-aligned
                }

                Text {
                    visible: text !== ""
                    text: card.time
                    color: card.dim
                    font.family: card.fontFamily
                    font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.summary
                textFormat: Text.PlainText
                color: card.fg
                font.family: card.fontFamily
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.bodyText
                textFormat: Text.StyledText
                color: card.bodyColor
                font.family: card.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // Action buttons, e.g. a reminder's snooze. Above the card's MouseArea, so they get the click.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: card.buttons.length > 0
                spacing: 6

                Repeater {
                    model: card.buttons

                    delegate: Rectangle {
                        id: button
                        required property var modelData

                        implicitWidth: buttonText.implicitWidth + 20
                        implicitHeight: buttonText.implicitHeight + 8
                        radius: 6
                        color: buttonArea.containsMouse ? Theme.muted : Theme.surface

                        Text {
                            id: buttonText
                            anchors.centerIn: parent
                            text: button.modelData.text
                            textFormat: Text.PlainText
                            color: buttonArea.containsMouse ? card.fg : card.bodyColor
                            font.family: card.fontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: buttonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.actionInvoked(button.modelData.identifier)
                        }
                    }
                }
            }
        }
    }

    // Close button, shown on hover. Declared after the card's MouseArea so it gets the click.
    Text {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 8
            rightMargin: 10
        }
        opacity: card.hovered ? 1 : 0
        text: "✕"
        color: closeArea.containsMouse ? card.fg : card.dim
        font.family: card.fontFamily
        font.pixelSize: 12

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            anchors.margins: -4
            enabled: card.hovered
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.closeRequested()
        }
    }

    // Time left, draining along the bottom edge
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            bottomMargin: card.border.width + 1
            leftMargin: card.radius
        }
        visible: card.progress > 0
        width: (card.width - 2 * card.radius) * card.progress
        height: 2
        radius: 1
        color: card.accent
        opacity: 0.6
    }
}
