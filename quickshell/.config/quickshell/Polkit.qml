// Polkit authentication agent: the password prompt for actions that need admin
// rights (mounting disks in Nautilus, system-wide NetworkManager connections, pkexec).
// After Omarchy's Quickshell agent, without its fingerprint mode.
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

Scope {
    id: root

    // Nord, light or dark (Theme.qml), matching the bar and notifications
    readonly property color bg: Theme.bg
    readonly property color fg: Theme.bright
    readonly property color dim: Theme.dim
    readonly property color accent: Theme.accent
    readonly property color urgent: Theme.urgent
    readonly property string fontFamily: Theme.fontFamily

    readonly property var flow: agent.flow
    property bool submitted: false
    property bool wrong: false
    property int shakeOffset: 0

    // "Authentication is needed to run `/usr/bin/foo' as the super user" → "Run /usr/bin/foo as root"
    function label(message) {
        const m = String(message || "").match(/^Authentication is (?:needed|required) to run [`']([^`']+)[`'] as /i);
        return m ? "Run " + m[1] + " as root" : String(message || "Authentication is required");
    }

    function submit() {
        if (!flow || !flow.isResponseRequired)
            return;
        submitted = true;
        wrong = false;
        flow.submit(password.text);
        password.text = "";
    }

    function cancel() {
        password.text = "";
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.submitted = false;
            root.wrong = false;
            password.text = "";
        }
        onIsRegisteredChanged: {
            if (!isRegistered)
                console.warn("polkit agent not registered; is another agent running?");
        }
    }

    Connections {
        target: root.flow

        // PAM asks again after a wrong password (polkit allows three tries)
        function onIsResponseRequiredChanged() {
            if (root.flow?.isResponseRequired) {
                root.submitted = false;
                password.forceActiveFocus();
            }
        }

        function onAuthenticationFailed() {
            root.submitted = false;
            root.wrong = true;
            shake.restart();
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 35; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    PanelWindow {
        visible: agent.isActive
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "#99000000"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        // A full-screen layer with exclusive focus takes the keyboard from every
        // window, so the password can't be typed into anything else by mistake
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) password.forceActiveFocus()

        MouseArea {
            anchors.fill: parent
            onClicked: password.forceActiveFocus()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.shakeOffset
            width: 420
            height: column.implicitHeight + 40
            radius: 10
            color: root.bg
            border.width: 2
            border.color: root.wrong ? root.urgent : root.accent

            Column {
                id: column
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 20
                }
                spacing: 14

                Text {
                    width: parent.width
                    text: "  " + root.label(root.flow?.message)
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: 14
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 6
                    color: Theme.surface
                    border.width: 1
                    border.color: password.activeFocus ? root.accent : Theme.muted

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: root.fg
                        selectionColor: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 15
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        readOnly: root.submitted
                        onAccepted: root.submit()
                        onTextEdited: root.wrong = false
                        Keys.onEscapePressed: root.cancel()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text.length === 0
                            text: root.submitted ? "Checking…" : root.wrong ? "Wrong password" : (root.flow?.inputPrompt || "Password").replace(/:\s*$/, "")
                            color: root.wrong ? root.urgent : root.dim
                            font: password.font
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.flow?.supplementaryMessage ?? ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.flow?.supplementaryIsError ? root.urgent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 12
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: "Enter to confirm · Esc to cancel"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
