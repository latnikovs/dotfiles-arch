// Mail (Thunderbird, special:mail) and Teams (a Chromium app window, special:teams) for the bar.
// Teams puts its unread count in the window title, "(3) Chat | … | Microsoft Teams". Thunderbird
// shares no count, so mail is only "new since you last looked": set by its notifications and
// cleared when the mail workspace shows. Teams notifications do the same when the title has no count.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    id: messaging

    property bool mailNew: false
    property bool teamsNew: false
    readonly property int teamsUnread: {
        let count = 0;
        for (const t of Hyprland.toplevels.values) {
            const m = /^\((\d+)\) .*Microsoft Teams$/.exec(t.title);
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

    // "mail", "teams" or "" for a notification (or a history entry, which has the same fields).
    // Chromium names itself as the app and puts the site in the body.
    function appOf(n): string {
        if (/thunderbird/i.test(n.appName))
            return "mail";
        if (/teams/i.test(n.appName) || /teams\.(microsoft\.com|cloud\.microsoft)/.test(n.summary + " " + n.body))
            return "teams";
        return "";
    }

    function noticed(n): void {
        const app = appOf(n);
        if (app === "mail" && !shown("mail"))
            mailNew = true;
        else if (app === "teams" && !shown("teams"))
            teamsNew = true;
    }

    // Runs showSpecial() from hyprland.lua, which animates like SUPER + M / SUPER + Y
    function show(app: string, toggle: bool): void {
        if (app)
            Quickshell.execDetached(["hyprctl", "eval", `showSpecial("${app}", ${toggle})`]);
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
        }
    }
}
