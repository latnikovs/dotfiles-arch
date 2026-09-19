// Top bar: workspaces on the left, clock and weather in the middle, tray/network/CPU/RAM/battery on the right.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: bar

    // Nord, matching the notification cards, wofi and Hyprland borders
    readonly property color bg: "#2e3440"
    readonly property color fg: "#d8dee9"
    readonly property color muted: "#4c566a"
    readonly property color warning: "#ebcb8b"
    readonly property color urgent: "#bf616a"

    required property Notifications notifications

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 26
    exclusionMode: ExclusionMode.Auto
    color: bg
    WlrLayershell.namespace: "bar"
    WlrLayershell.layer: WlrLayer.Top

    component BarText: Text {
        color: "#d8dee9"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }

    // ---- Tooltip, shared by every module

    function showTooltip(item, text) {
        tooltip.target = item;
        tooltip.text = text;
        tooltipAnchor.updateAnchor();
    }

    function hideTooltip(item) {
        if (tooltip.target === item)
            tooltip.target = null;
    }

    PopupWindow {
        id: tooltip
        property Item target: null
        property string text: ""

        visible: target !== null && text !== ""
        color: "transparent"
        implicitWidth: tooltipLabel.implicitWidth + 16
        implicitHeight: tooltipLabel.implicitHeight + 10

        anchor {
            id: tooltipAnchor
            window: bar
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1
            onAnchoring: {
                const target = tooltip.target;
                if (!target)
                    return;
                const p = bar.contentItem.mapFromItem(target, target.width / 2 - tooltip.implicitWidth / 2, target.height + 4);
                tooltipAnchor.rect.x = Math.round(p.x);
                tooltipAnchor.rect.y = Math.round(p.y);
            }
        }

        Rectangle {
            anchors.fill: parent
            color: bar.bg
            border.color: bar.muted
            border.width: 1
            radius: 6

            BarText {
                id: tooltipLabel
                anchors.centerIn: parent
                text: tooltip.text
            }
        }
    }

    // ---- Workspaces: 1-5 always, plus any other open ones up to 10

    readonly property var workspaceIds: {
        const ids = [1, 2, 3, 4, 5];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0 && ws.id <= 10 && !ids.includes(ws.id))
                ids.push(ws.id);
        }
        return ids.sort((a, b) => a - b);
    }

    function workspace(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id) ?? null;
    }

    RowLayout {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            leftMargin: 8
        }
        spacing: 3

        Repeater {
            model: bar.workspaceIds

            delegate: MouseArea {
                required property int modelData
                readonly property var workspace: bar.workspace(modelData)
                readonly property bool focused: Hyprland.focusedWorkspace?.id === modelData
                readonly property bool empty: !workspace || workspace.toplevels.values.length === 0

                Layout.fillHeight: true
                implicitWidth: Math.max(21, label.implicitWidth + 12)
                cursorShape: Qt.PointingHandCursor
                // Through hyprctl because this Hyprland is configured in Lua
                onClicked: Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${modelData} })`])

                BarText {
                    id: label
                    anchors.centerIn: parent
                    text: modelData === 10 ? "0" : String(modelData)
                    font.bold: parent.focused
                    color: parent.workspace?.urgent ? bar.urgent : parent.empty && !parent.focused ? bar.muted : bar.fg
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 2
                    visible: parent.focused
                    color: bar.fg
                }
            }
        }
    }

    // ---- Clock: click for the date

    property bool showDate: false

    function isoWeek(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    MouseArea {
        id: clockArea
        anchors.centerIn: parent
        width: clockText.implicitWidth
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.showDate = !bar.showDate

        BarText {
            id: clockText
            anchors.centerIn: parent
            text: bar.showDate
                ? `${Qt.formatDate(clock.date, "dd MMMM")} W${String(bar.isoWeek(clock.date)).padStart(2, "0")} ${clock.date.getFullYear()}`
                : Qt.formatDateTime(clock.date, "dddd HH:mm")
        }
    }

    // ---- Weather, right of the clock: current conditions from wttr.in (location by IP),
    //      then the next three days from open-meteo (wttr.in only has two). Polled every 15min.

    property var weather: null
    property var forecast: []
    property bool weatherOpen: false

    // wttr.in weather codes to Nerd Font glyphs, same mapping as Omarchy
    function weatherIcon(code, night) {
        switch (code) {
        case 113: return night ? "" : "";
        case 116: return night ? "" : "";
        case 143: case 248: case 260: return night ? "" : "";
        case 176: case 263: case 353: return night ? "" : "";
        case 179: case 227: case 230: case 323: case 326: case 368: return night ? "" : "";
        case 182: case 185: case 281: case 284: case 311: case 314:
        case 317: case 320: case 350: case 362: case 365: case 374: case 377: return "";
        case 200: case 386: case 389: case 392: case 395: return "";
        case 266: case 293: case 296: case 299: case 302: case 305: case 308: case 356: case 359: return "";
        case 329: case 332: case 335: case 338: case 371: return "";
        default: return ""; // cloudy (119, 122)
        }
    }

    // Open-meteo (WMO) codes, via the closest wttr.in code
    function openMeteoIcon(code) {
        if (code === 0) return weatherIcon(113, false);
        if (code === 1 || code === 2) return weatherIcon(116, false);
        if (code === 45 || code === 48) return weatherIcon(143, false);
        if ([51, 53, 55, 56, 57, 61].includes(code)) return weatherIcon(266, false);
        if ([63, 65, 66, 67, 80, 81, 82].includes(code)) return weatherIcon(308, false);
        if ([71, 73, 75, 77, 85, 86].includes(code)) return weatherIcon(338, false);
        if ([95, 96, 99].includes(code)) return weatherIcon(389, false);
        return weatherIcon(119, false);
    }

    // "07:23 AM" -> minutes since midnight
    function wttrMinutes(time) {
        const m = /(\d+):(\d+) ([AP]M)/.exec(time ?? "");
        return m ? (Number(m[1]) % 12 + (m[3] === "PM" ? 12 : 0)) * 60 + Number(m[2]) : -1;
    }

    Process {
        id: weatherProc
        command: ["curl", "-fsS", "--max-time", "10", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const c = d.current_condition[0];
                    const today = d.weather[0];
                    const now = clock.date.getHours() * 60 + clock.date.getMinutes();
                    const sunrise = bar.wttrMinutes(today.astronomy[0].sunrise);
                    const sunset = bar.wttrMinutes(today.astronomy[0].sunset);
                    const area = d.nearest_area[0];
                    bar.weather = {
                        icon: bar.weatherIcon(Number(c.weatherCode), sunrise >= 0 && sunset >= 0 && (now < sunrise || now >= sunset)),
                        temp: c.temp_C,
                        description: c.weatherDesc[0].value,
                        location: area.areaName[0].value,
                        feels: `${c.FeelsLikeC}°C`,
                        wind: `${c.windspeedKmph} km/h`,
                        humidity: `${c.humidity}%`
                    };
                    weatherTimer.interval = 15 * 60 * 1000;
                    forecastProc.command = ["curl", "-fsS", "--max-time", "5",
                        `https://api.open-meteo.com/v1/forecast?latitude=${area.latitude}&longitude=${area.longitude}`
                        + "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=4&timezone=auto"];
                    forecastProc.running = true;
                } catch (e) {
                    // Keep the last report and retry soon: wttr.in is often slow or flaky
                    weatherTimer.interval = 60 * 1000;
                }
            }
        }
    }

    Process {
        id: forecastProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const daily = JSON.parse(text).daily;
                    // Index 0 is today
                    bar.forecast = daily.time.slice(1, 4).map((date, i) => ({
                        name: Qt.formatDate(new Date(`${date}T12:00:00`), "dddd"),
                        icon: bar.openMeteoIcon(daily.weather_code[i + 1]),
                        max: `${Math.round(daily.temperature_2m_max[i + 1])}°`,
                        min: `${Math.round(daily.temperature_2m_min[i + 1])}°`
                    }));
                } catch (e) {
                    // Keep the last forecast
                }
            }
        }
    }

    Timer {
        id: weatherTimer
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    // Left click opens the forecast, middle click refreshes
    MouseArea {
        id: weatherButton
        anchors {
            left: clockArea.right
            leftMargin: 12
            verticalCenter: parent.verticalCenter
        }
        width: weatherText.implicitWidth
        height: parent.height
        visible: bar.weather !== null
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                weatherProc.running = true;
                return;
            }
            bar.weatherOpen = !bar.weatherOpen;
            if (bar.weatherOpen)
                bar.notifications.historyOpen = false;
        }

        BarText {
            id: weatherText
            anchors.centerIn: parent
            text: bar.weather ? `${bar.weather.icon} ${bar.weather.temp}°C` : ""
        }
    }

    component Caption: BarText {
        color: Qt.darker(bar.fg, 1.4)
        font.pixelSize: 10
        font.letterSpacing: 1
    }

    PopupWindow {
        id: weatherPanel
        visible: bar.weatherOpen && bar.weather !== null
        color: "transparent"
        implicitWidth: Math.max(480, weatherColumn.implicitWidth + 40)
        implicitHeight: weatherColumn.implicitHeight + 46

        // Centered on the bar, like Omarchy
        anchor {
            window: bar
            rect.x: Math.round((bar.width - weatherPanel.implicitWidth) / 2)
            rect.y: bar.height
            rect.width: 1
            rect.height: 1
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
        }

        Rectangle {
            anchors {
                fill: parent
                topMargin: 6
            }
            color: bar.bg
            border.color: bar.muted
            border.width: 1
            radius: 10
            focus: true
            Keys.onEscapePressed: bar.weatherOpen = false

            ColumnLayout {
                id: weatherColumn
                anchors {
                    fill: parent
                    topMargin: 20
                    bottomMargin: 20
                    leftMargin: 20
                    rightMargin: 20
                }
                spacing: 16

                // Hero: big icon and temperature, then location and stats on the right
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    BarText {
                        Layout.topMargin: 6
                        text: bar.weather?.icon ?? ""
                        font.pixelSize: 56
                    }

                    RowLayout {
                        spacing: 2

                        BarText {
                            text: bar.weather?.temp ?? ""
                            font.pixelSize: 52
                            font.bold: true
                        }

                        BarText {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 8
                            text: "°C"
                            font.pixelSize: 22
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        spacing: 12

                        Caption {
                            text: ` ${bar.weather?.location ?? ""} · ${bar.weather?.description ?? ""}`.toUpperCase()
                            font.pixelSize: 12
                        }

                        RowLayout {
                            spacing: 32

                            Repeater {
                                model: [["FEELS", bar.weather?.feels], ["WIND", bar.weather?.wind], ["HUMID", bar.weather?.humidity]]

                                delegate: ColumnLayout {
                                    required property var modelData
                                    spacing: 4

                                    Caption {
                                        text: modelData[0]
                                    }

                                    BarText {
                                        text: modelData[1] ?? ""
                                        font.pixelSize: 16
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    visible: bar.forecast.length > 0
                    color: bar.fg
                    opacity: 0.12
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.forecast.length > 0
                    spacing: 44

                    Repeater {
                        model: bar.forecast

                        delegate: RowLayout {
                            required property var modelData
                            spacing: 10

                            BarText {
                                text: modelData.icon
                                font.pixelSize: 26
                            }

                            ColumnLayout {
                                spacing: 2

                                Caption {
                                    text: modelData.name.toUpperCase()
                                }

                                RowLayout {
                                    spacing: 6

                                    BarText {
                                        text: modelData.max
                                        font.pixelSize: 13
                                    }

                                    BarText {
                                        text: modelData.min
                                        color: Qt.darker(bar.fg, 1.5)
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Clicking anywhere else closes the forecast (the bar is included so the widget can toggle it)
    HyprlandFocusGrab {
        windows: [weatherPanel, bar]
        active: weatherPanel.visible
        onCleared: bar.weatherOpen = false
    }

    // ---- Network, polled every 5s

    property var net: ({ type: "disconnected" })

    Process {
        id: netProc
        command: [Quickshell.shellDir + "/scripts/network-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    bar.net = JSON.parse(text);
                } catch (e) {
                    bar.net = { type: "disconnected" };
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    // ---- CPU usage from /proc/stat, polled every 5s

    property real cpuUsage: 0
    property var cpuLast: null

    Process {
        id: cpuProc
        command: ["head", "-1", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/).slice(1).map(Number);
                const idle = f[3] + f[4]; // idle + iowait
                const total = f.reduce((a, b) => a + b, 0);
                if (bar.cpuLast && total > bar.cpuLast.total)
                    bar.cpuUsage = 1 - (idle - bar.cpuLast.idle) / (total - bar.cpuLast.total);
                bar.cpuLast = { idle, total };
            }
        }
    }

    // ---- Memory usage from /proc/meminfo, polled with the CPU

    property real memUsage: 0
    property string memDetail: ""

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = key => Number(new RegExp(`^${key}:\\s+(\\d+)`, "m").exec(text)?.[1] ?? 0);
                const total = kb("MemTotal");
                const used = total - kb("MemAvailable");
                if (total > 0) {
                    bar.memUsage = used / total;
                    bar.memDetail = `RAM ${(used / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(1)} GiB`;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
        }
    }

    // ---- Notification history, dropping down from the bell

    function historyTime(date) {
        const today = new Date().toDateString() === date.toDateString();
        return Qt.formatDateTime(date, today ? "HH:mm" : "dd MMM HH:mm");
    }

    PopupWindow {
        id: historyPanel
        visible: bar.notifications.historyOpen && Hyprland.focusedMonitor?.name === bar.screen.name
        color: "transparent"
        implicitWidth: 400
        implicitHeight: Math.min(historyColumn.implicitHeight + 26, bar.screen.height * 0.7)

        // Right-aligned with the toasts (Hyprland's gaps_out, 6)
        anchor {
            window: bar
            rect.x: bar.width - historyPanel.implicitWidth - 6
            rect.y: bar.height
            rect.width: 1
            rect.height: 1
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
        }

        Rectangle {
            anchors {
                fill: parent
                topMargin: 6
            }
            color: bar.bg
            border.color: bar.muted
            border.width: 1
            radius: 10
            focus: true
            Keys.onEscapePressed: bar.notifications.historyOpen = false

            ColumnLayout {
                id: historyColumn
                anchors {
                    fill: parent
                    margins: 10
                }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    BarText {
                        Layout.fillWidth: true
                        text: "Notifications"
                        font.bold: true
                    }

                    BarText {
                        visible: bar.notifications.history.length > 0
                        text: "Clear"
                        color: clearArea.containsMouse ? bar.fg : bar.muted

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.notifications.history = []
                        }
                    }
                }

                BarText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    visible: bar.notifications.history.length === 0
                    text: "No notifications"
                    color: bar.muted
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: contentHeight
                    visible: count > 0
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: bar.notifications.history

                    // Clicking an entry removes it: the app stopped listening for
                    // actions when the notification closed.
                    delegate: NotificationCard {
                        required property var modelData
                        width: ListView.view.width
                        appName: modelData.appName
                        summary: modelData.summary
                        body: modelData.body
                        image: modelData.image
                        appIcon: modelData.appIcon
                        urgency: modelData.urgency
                        time: bar.historyTime(modelData.time)
                        onActivated: bar.notifications.forget(modelData.key)
                        onCloseRequested: bar.notifications.forget(modelData.key)
                    }
                }
            }
        }
    }

    // Clicking anywhere else closes the history (the bar is included so the bell can toggle it)
    HyprlandFocusGrab {
        windows: [historyPanel, bar]
        active: historyPanel.visible
        onCleared: bar.notifications.historyOpen = false
    }

    // ---- Right side

    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: Math.round(battery.percentage * 100)
    readonly property bool charging: battery.state === UPowerDeviceState.Charging

    RowLayout {
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
            rightMargin: 15
        }
        spacing: 15

        RowLayout {
            spacing: 12
            visible: SystemTray.items.values.length > 0

            Repeater {
                model: SystemTray.items

                delegate: MouseArea {
                    id: trayItem
                    required property SystemTrayItem modelData

                    implicitWidth: 12
                    implicitHeight: 12
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: containsMouse ? bar.showTooltip(this, modelData.tooltipTitle || modelData.title) : bar.hideTooltip(this)
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (modelData.hasMenu && (mouse.button === Qt.RightButton || modelData.onlyMenu)) {
                            const p = mapToItem(bar.contentItem, 0, height + 4);
                            modelData.display(bar, p.x, p.y);
                        } else {
                            modelData.activate();
                        }
                    }

                    IconImage {
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                        implicitSize: 12
                    }
                }
            }
        }

        // Bell: left click toggles do-not-disturb, right click opens the history
        MouseArea {
            id: bell
            implicitWidth: dndIcon.implicitWidth
            Layout.fillHeight: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, bar.notifications.dnd ? "Notifications silenced" : "Notifications on") : bar.hideTooltip(this)
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    bar.hideTooltip(this);
                    bar.notifications.historyOpen = !bar.notifications.historyOpen;
                    bar.weatherOpen = false;
                    return;
                }
                bar.notifications.dnd = !bar.notifications.dnd;
                bar.showTooltip(this, bar.notifications.dnd ? "Notifications silenced" : "Notifications on");
            }

            BarText {
                id: dndIcon
                anchors.centerIn: parent
                text: bar.notifications.dnd ? "󰂛" : "󰂚"
            }
        }

        MouseArea {
            implicitWidth: netIcon.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            onContainsMouseChanged: {
                const n = bar.net;
                const tip = n.type === "wifi" ? `${n.ssid || n.dev} (${n.signal}%)` : n.type === "ethernet" ? `${n.dev} ${n.ip}` : "Disconnected";
                containsMouse ? bar.showTooltip(this, tip) : bar.hideTooltip(this);
            }

            BarText {
                id: netIcon
                anchors.centerIn: parent
                text: bar.net.type === "wifi" ? ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(bar.net.signal / 20))] : bar.net.type === "ethernet" ? "󰈀" : "󰤮"
            }
        }

        BarText {
            text: ` ${Math.round(bar.cpuUsage * 100)}%`
            color: bar.cpuUsage >= 0.9 ? bar.urgent : bar.fg
        }

        MouseArea {
            implicitWidth: memText.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, bar.memDetail) : bar.hideTooltip(this)

            BarText {
                id: memText
                anchors.centerIn: parent
                text: ` ${Math.round(bar.memUsage * 100)}%`
                color: bar.memUsage >= 0.9 ? bar.urgent : bar.fg
            }
        }

        BarText {
            visible: bar.battery.isLaptopBattery
            text: `${bar.batteryPercent}% ${bar.charging ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(bar.batteryPercent / 20))]}`
            color: bar.batteryPercent <= 10 ? bar.urgent : bar.batteryPercent <= 20 ? bar.warning : bar.fg
        }
    }
}
