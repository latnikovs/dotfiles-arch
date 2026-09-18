// One notification toast. Presentational only: shell.qml drives the countdown and actions.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card

    required property Notification notification
    property real progress: 0 // 1 → 0 as the toast times out; 0 hides the bar
    readonly property alias hovered: hover.hovered

    signal activated
    signal closeRequested

    // Nord, matching waybar, wofi and Hyprland borders
    readonly property color fg: "#eceff4"
    readonly property color bodyColor: "#d8dee9"
    readonly property color dim: "#7b88a1"
    readonly property color accent: "#88c0d0"
    readonly property color urgent: "#bf616a"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property string iconSource: source(notification.image) || source(notification.appIcon)

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
    color: "#2e3440"
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

            Text {
                Layout.fillWidth: true
                visible: text !== "" && text !== card.notification.summary
                text: card.notification.appName
                textFormat: Text.PlainText
                color: card.dim
                font.family: card.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.summary
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
                text: card.notification.body
                textFormat: Text.StyledText
                color: card.bodyColor
                font.family: card.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
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
