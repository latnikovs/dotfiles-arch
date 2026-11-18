// Login screen for greetd, with the lock screen's look (hypr/hyprlock.conf): the
// wallpaper blurred and darkened, the clock, the date and a password field, in
// Nord dark. The wallpaper shows on every monitor, the form on the focused one.
// install.sh puts this in /etc/greetd/quickshell/; dotfiles-greeter runs it.
//
// Outside greetd it runs as a preview (quickshell -p greeter/shell.qml): nothing
// logs in, every password is wrong and Escape quits.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland

ShellRoot {
    id: root

    // Nord dark, as in the bar's Theme.qml; the login screen doesn't follow darkman
    readonly property color bg: "#2e3440"
    readonly property color fg: "#d8dee9"
    readonly property color bright: "#eceff4"
    readonly property color dim: "#7b88a1"
    readonly property color accent: "#88c0d0"
    readonly property color warning: "#ebcb8b"
    readonly property color urgent: "#bf616a"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    readonly property bool preview: !Greetd.available
    readonly property string session: "/usr/local/bin/hyprland-session"
    readonly property string wallpaper: Quickshell.env("DOTFILES_GREETER_WALLPAPER") || "/etc/greetd/wallpaper.jpg"

    // The machine's user, from greetd's config.toml (install.sh); asked for when unset,
    // and after Escape
    property string user: Quickshell.env("DOTFILES_GREETER_USER") || ""
    property bool askUser: user === ""
    // PAM's current question ("Password:") and whether the answer may show
    property string prompt: ""
    property bool echo: false
    property bool busy: false
    property bool wrong: false
    // PAM's info and error lines (expired password, locked account)
    property string message: ""
    property int shakeOffset: 0
    // The form fades in and rises a little when the greeter appears
    property real reveal: 0
    property real rise: 24
    // From /etc/passwd's comment field; empty when the account has no full name
    property string fullName: ""
    property string hostname: ""

    function greeting() {
        const h = clock.date.getHours();
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    }

    signal focusInput

    function start() {
        busy = false;
        if (askUser) {
            prompt = "Username";
            echo = true;
        } else if (preview) {
            prompt = "Password";
            echo = false;
        } else {
            busy = true;
            Greetd.createSession(user);
        }
        focusInput();
    }

    function submit(text) {
        if (busy)
            return;
        message = "";
        if (askUser) {
            if (text.trim() === "")
                return;
            user = text.trim();
            askUser = false;
            start();
        } else if (preview) {
            fail("");
        } else {
            busy = true;
            Greetd.respond(text);
        }
    }

    // A wrong password ends greetd's session, so a new one starts for the next try.
    // Not from inside the signal: Quickshell emits authFailure and error before it
    // cancels and resets its own session, so a session created there is cancelled
    // straight away, and the next right password reaches a greeter that no longer
    // expects it and never launches.
    function fail(why) {
        wrong = true;
        message = why;
        shake.restart();
        Qt.callLater(start);
    }

    function switchUser() {
        if (preview && !askUser) {
            Qt.quit();
            return;
        }
        if (!preview)
            Greetd.cancelSession();
        wrong = false;
        message = "";
        askUser = true;
        start();
    }

    Component.onCompleted: {
        start();
        intro.start();
    }

    ParallelAnimation {
        id: intro
        NumberAnimation { target: root; property: "reveal"; to: 1; duration: 600; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "rise"; to: 0; duration: 700; easing.type: Easing.OutCubic }
    }

    onUserChanged: fullNameQuery.running = user !== ""

    Process {
        id: fullNameQuery
        running: root.user !== ""
        command: ["getent", "passwd", root.user]
        stdout: StdioCollector {
            onStreamFinished: root.fullName = (text.split(":")[4] || "").split(",")[0].trim()
        }
    }

    FileView {
        path: "/etc/hostname"
        onLoaded: root.hostname = text().trim()
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                root.prompt = message.replace(/:\s*$/, "");
                root.echo = echoResponse;
                root.busy = false;
                root.focusInput();
            } else {
                root.message = message;
            }
        }

        function onAuthFailure(message) {
            root.fail("");
        }

        function onError(error) {
            root.fail(error);
        }

        function onReadyToLaunch() {
            Greetd.launch([root.session], [], true);
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeOffset"; to: -10; duration: 35; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 10; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: power
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property ShellScreen modelData
            readonly property bool hasForm: modelData.name === (Hyprland.focusedMonitor?.name ?? Quickshell.screens[0].name)

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: root.bg
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            // The preview runs inside a normal session and mustn't hold on to the keyboard
            WlrLayershell.keyboardFocus: hasForm ? (root.preview ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

            Image {
                id: wallpaper
                anchors.fill: parent
                source: "file://" + root.wallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: wallpaper
                visible: wallpaper.status === Image.Ready
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                brightness: -0.3
                saturation: 0.17
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.focusInput()
            }

            // Darker towards the bottom, under the hostname and power buttons
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#002e3440" }
                    GradientStop { position: 0.55; color: "#002e3440" }
                    GradientStop { position: 1.0; color: "#b32e3440" }
                }
            }

            Column {
                id: form
                visible: window.hasForm
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 40 + root.rise
                opacity: root.reveal
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd  d MMMM").toUpperCase()
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    font.letterSpacing: 6
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.StyledText
                    text: Qt.formatDateTime(clock.date, "HH") + "<font color=\"" + root.accent + "\">:</font>" + Qt.formatDateTime(clock.date, "mm")
                    color: root.bright
                    font.family: root.fontFamily
                    font.pixelSize: 200
                    font.weight: Font.Thin
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.askUser ? "Who's there?" : root.greeting() + ", " + (root.fullName || root.user)
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Light
                }

                Item {
                    width: 1
                    height: 36
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.shakeOffset
                    width: 320
                    height: 52
                    radius: height / 2
                    color: input.activeFocus ? "#992e3440" : "#662e3440"
                    border.width: 1
                    border.color: root.wrong ? root.urgent : root.busy ? root.warning : input.text.length > 0 ? root.accent : "#40eceff4"

                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 26
                        anchors.rightMargin: 26
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        clip: true
                        color: root.bright
                        selectionColor: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: root.echo ? 18 : 22
                        font.letterSpacing: root.echo ? 0 : 4
                        echoMode: root.echo ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        // The dots show where you are; a caret would sit on the placeholder
                        cursorDelegate: Rectangle {
                            width: 2
                            color: root.accent
                            visible: root.echo && input.text.length > 0
                        }
                        readOnly: root.busy
                        onAccepted: {
                            const answer = text;
                            text = "";
                            root.submit(answer);
                        }
                        onTextEdited: root.wrong = false
                        Keys.onEscapePressed: {
                            text = "";
                            root.switchUser();
                        }

                        Connections {
                            target: root
                            function onFocusInput() {
                                if (window.hasForm)
                                    input.forceActiveFocus();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: input.text.length === 0
                            text: root.busy ? "Checking…"
                                : root.wrong ? (root.askUser ? "Unknown user" : "Wrong password")
                                : root.askUser ? "Username"
                                : root.prompt
                            color: root.wrong ? root.urgent : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 16
                            font.italic: !root.wrong
                        }
                    }
                }

                Item {
                    width: 1
                    height: 18
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 420
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: root.message || (root.preview ? "Preview: Escape to quit" : root.askUser ? "" : "Esc: other user")
                    color: root.message ? root.urgent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 13
                }
            }

            // The machine's name, bottom left, across from the power buttons
            Text {
                visible: window.hasForm
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 32
                opacity: root.reveal
                text: "\uf108   " + root.hostname
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 15
                font.letterSpacing: 2
            }

            // Restart and shut down, bottom right (logind lets the login screen do both)
            Row {
                visible: window.hasForm
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 32
                spacing: 28
                opacity: root.reveal

                Repeater {
                    model: [
                        { icon: "󰜉", verb: "reboot" },
                        { icon: "󰐥", verb: "poweroff" }
                    ]

                    Text {
                        required property var modelData
                        text: modelData.icon
                        color: mouse.containsMouse ? root.accent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: 24

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.preview)
                                    return;
                                power.command = ["systemctl", parent.modelData.verb];
                                power.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
