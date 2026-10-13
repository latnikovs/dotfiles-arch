// Mail (Thunderbird, special:mail), Teams and WhatsApp (Chromium app windows, special:teams and
// special:whatsapp) for the bar. Teams and WhatsApp put their unread count in the window title,
// "(3) Chat | … | Microsoft Teams" and "(3) WhatsApp". Thunderbird shares no count, so mail is
// only "new since you last looked": set by its notifications and cleared when the mail workspace
// shows. Teams and WhatsApp notifications do the same when the title has no count.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    id: messaging

    property bool mailNew: false
    property bool teamsNew: false
    property bool whatsappNew: false
    readonly property int teamsUnread: unread(/^\((\d+)\) .*Microsoft Teams$/)
    readonly property int whatsappUnread: unread(/^\((\d+)\) WhatsApp$/)

    // The count from the first window whose title matches, 0 without one
    function unread(title: var): int {
        let count = 0;
        for (const t of Hyprland.toplevels.values) {
            const m = title.exec(t.title);
            if (m)
                count = Math.max(count, Number(m[1]));
        }
        return count;
    }

    // Special workspace showing on each monitor, e.g. { "DP-1": "special:mail" }
    property var shownSpecial: ({})

    function shown(app: string): bool {
        return Object.values(shownSpecial).includes("special:" + app);
    }

    // "mail", "teams", "whatsapp" or "" for a notification (or a history entry, which has the same fields).
    // Chromium names itself as the app and puts the site in the body.
    function appOf(n): string {
        if (/thunderbird/i.test(n.appName))
            return "mail";
        if (/teams/i.test(n.appName) || /teams\.(microsoft\.com|cloud\.microsoft)/.test(n.summary + " " + n.body))
            return "teams";
        if (/web\.whatsapp\.com/.test(n.summary + " " + n.body))
            return "whatsapp";
        return "";
    }

    function noticed(n): void {
        const app = appOf(n);
        if (app === "mail" && !shown("mail"))
            mailNew = true;
        else if (app === "teams" && !shown("teams"))
            teamsNew = true;
        else if (app === "whatsapp" && !shown("whatsapp"))
            whatsappNew = true;
    }

    // Runs showSpecial() from hyprland.lua, which animates like SUPER + M / SUPER + Y
    function show(app: string, toggle: bool): void {
        if (app)
            Quickshell.execDetached(["hyprctl", "eval", `showSpecial("${app}", ${toggle})`]);
    }

    // Teams call mode: a small pinned window in the top right corner (SUPER + SHIFT + Y)
    function toggleTeamsCall(): void {
        Quickshell.execDetached(["hyprctl", "eval", "toggleTeamsCall()"]);
    }

    // For a notification click: bring its app up
    function reveal(n): void {
        show(appOf(n), false);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "activespecial")
                return;
            // "special:mail,DP-1" when shown, ",DP-1" when hidden
            const [name, monitor] = event.data.split(",");
            messaging.shownSpecial = Object.assign({}, messaging.shownSpecial, { [monitor]: name });
            if (name === "special:mail")
                messaging.mailNew = false;
            else if (name === "special:teams")
                messaging.teamsNew = false;
            else if (name === "special:whatsapp")
                messaging.whatsappNew = false;
        }
    }
}
