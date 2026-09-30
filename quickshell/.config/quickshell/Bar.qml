// Top bar: workspaces on the left, clock (with calendar) and weather in the middle, pending updates/tray/keyboard layout/
// CPU/RAM/battery/microphone in use/volume/Bluetooth/Tailscale/network/notifications on the right. Mail and Teams follow the weather.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: bar

    // Nord, light or dark (Theme.qml), matching the notification cards, fuzzel and Hyprland borders
    readonly property color bg: Theme.bg
    readonly property color fg: Theme.fg
    readonly property color muted: Theme.muted
    readonly property color warning: Theme.warning
    readonly property color urgent: Theme.urgent
    readonly property color accent: Theme.accent

    required property Notifications notifications
    required property Keyboard keyboard
    required property Tailscale tailscale
    required property Messaging messaging
    required property Updates updates

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

    // ---- Keys for the dropdowns. Hyprland may give keyboard focus to the bar rather than the
    //      open popup, so both hand their keys here.

    // Esc closes; in the calendar Left/Right (h/l) step months, Up/Down (k/j) years, Enter goes back to today;
    // in the layout selector Up/Down (k/j) move and Enter picks; a Wi-Fi password prompt takes every key
    function panelKey(event) {
        const k = event.key;
        if (networkPanel.open && networkPanel.handleKey(event)) {
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Escape) {
            closePanels();
        } else if (layoutOpen) {
            const n = keyboard.layouts.length;
            if ([Qt.Key_Up, Qt.Key_K, Qt.Key_Down, Qt.Key_J].includes(k))
                layoutCursor = (layoutCursor + ([Qt.Key_Up, Qt.Key_K].includes(k) ? n - 1 : 1)) % n;
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                selectLayout(layoutCursor);
            else
                return;
        } else if (!calendarOpen) {
            return;
        } else if ([Qt.Key_Left, Qt.Key_H, Qt.Key_Right, Qt.Key_L].includes(k)) {
            moveCalendar([Qt.Key_Left, Qt.Key_H].includes(k) ? -1 : 1);
        } else if ([Qt.Key_Up, Qt.Key_K, Qt.Key_Down, Qt.Key_J].includes(k)) {
            moveCalendar([Qt.Key_Up, Qt.Key_K].includes(k) ? -12 : 12);
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            calendarView = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
        } else {
            return;
        }
        event.accepted = true;
    }

    Item {
        focus: true
        Keys.onPressed: event => bar.panelKey(event)
    }

    // One dropdown at a time
    function closePanels() {
        calendarOpen = false;
        weatherOpen = false;
        layoutOpen = false;
        notifications.historyOpen = false;
        audioPanel.open = false;
        networkPanel.open = false;
        bluetoothPanel.open = false;
        tailscalePanel.open = false;
    }

    function toggleDropdown(panel) {
        const open = !panel.open;
        closePanels();
        panel.open = open;
    }

    function toggleAudio() {
        toggleDropdown(audioPanel);
    }

    function toggleNetwork() {
        toggleDropdown(networkPanel);
    }

    function toggleBluetooth() {
        if (btAdapter)
            toggleDropdown(bluetoothPanel);
    }

    function toggleTailscale() {
        if (tailscale.available)
            toggleDropdown(tailscalePanel);
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

    // ---- Clock: left click for the calendar, right click for the date

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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                bar.showDate = !bar.showDate;
                return;
            }
            bar.toggleCalendar();
        }

        BarText {
            id: clockText
            anchors.centerIn: parent
            text: bar.showDate
                ? `${Qt.formatDate(clock.date, "dd MMMM")} W${String(bar.isoWeek(clock.date)).padStart(2, "0")} ${clock.date.getFullYear()}`
                : Qt.formatDateTime(clock.date, "HH:mm")
        }
    }

    // ---- Calendar, dropping down from the clock (after Omarchy's): today, the year's
    //      progress, and a month grid with ISO week numbers. Weeks start on Monday.

    property bool calendarOpen: false
    property date calendarView: new Date()

    readonly property bool viewingThisMonth: calendarView.getFullYear() === clock.date.getFullYear() && calendarView.getMonth() === clock.date.getMonth()

    readonly property real yearDone: {
        const y = clock.date.getFullYear();
        const day = Math.round((new Date(y, clock.date.getMonth(), clock.date.getDate()) - new Date(y, 0, 1)) / 86400000);
        return day / (new Date(y, 1, 29).getMonth() === 1 ? 366 : 365);
    }

    // Grid cells, row by row: each week's ISO number, then its seven days.
    // Always six rows, so the panel keeps its height from month to month.
    readonly property var calendarCells: {
        const y = calendarView.getFullYear();
        const m = calendarView.getMonth();
        const offset = (new Date(y, m, 1).getDay() + 6) % 7; // days since Monday
        const today = clock.date.toDateString();
        const cells = [];
        for (let w = 0; w < 6; w++) {
            cells.push({ week: isoWeek(new Date(y, m, 1 - offset + w * 7)) });
            for (let i = 0; i < 7; i++) {
                const d = new Date(y, m, 1 - offset + w * 7 + i);
                cells.push({ day: d.getDate(), inMonth: d.getMonth() === m, weekend: i >= 5, today: d.toDateString() === today });
            }
        }
        return cells;
    }

    function toggleCalendar() {
        const open = !calendarOpen;
        closePanels();
        calendarOpen = open;
        if (open)
            calendarView = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
    }

    function moveCalendar(months) {
        calendarView = new Date(calendarView.getFullYear(), calendarView.getMonth() + months, 1);
    }

    PopupWindow {
        id: calendarPanel
        visible: bar.calendarOpen
        color: "transparent"
        implicitWidth: calendarColumn.implicitWidth + 48
        implicitHeight: calendarColumn.implicitHeight + 46

        anchor {
            window: bar
            rect.x: Math.round((bar.width - calendarPanel.implicitWidth) / 2)
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
            Keys.onPressed: event => bar.panelKey(event)

            ColumnLayout {
                id: calendarColumn
                anchors {
                    fill: parent
                    topMargin: 20
                    bottomMargin: 20
                    leftMargin: 24
                    rightMargin: 24
                }
                spacing: 18

                // Hero: today. Clicking it comes back from another month.
                MouseArea {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: heroRow.implicitWidth
                    implicitHeight: heroRow.implicitHeight
                    enabled: !bar.viewingThisMonth
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: bar.calendarView = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)

                    RowLayout {
                        id: heroRow
                        spacing: 18

                        BarText {
                            text: "󰃭"
                            font.pixelSize: 40
                            color: parent.parent.containsMouse ? bar.accent : bar.fg
                        }

                        BarText {
                            text: Qt.formatDate(clock.date, "MMMM d")
                            font.pixelSize: 44
                            font.bold: true
                            color: parent.parent.containsMouse ? bar.accent : bar.fg
                        }
                    }
                }

                // Year progress: whole days done over days in the year
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Caption {
                        text: clock.date.getFullYear()
                        font.pixelSize: 11
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Qt.rgba(bar.fg.r, bar.fg.g, bar.fg.b, 0.12)

                        Rectangle {
                            width: Math.round(parent.width * bar.yearDone)
                            height: parent.height
                            radius: parent.radius
                            color: bar.accent
                        }
                    }

                    BarText {
                        text: `${Math.round(bar.yearDone * 100)}%`
                        font.pixelSize: 11
                    }
                }

                // Month grid, scroll to change month
                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 8
                    rowSpacing: 2
                    columnSpacing: 2

                    WheelHandler {
                        onWheel: event => {
                            if (event.angleDelta.y !== 0)
                                bar.moveCalendar(event.angleDelta.y > 0 ? -1 : 1);
                        }
                    }

                    Caption {
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignHCenter
                        text: "W"
                        font.bold: true
                        color: Qt.darker(bar.fg, 1.9)
                    }

                    Repeater {
                        model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                        delegate: Caption {
                            required property string modelData
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.bold: true
                            color: Qt.darker(bar.fg, 1.5)
                        }
                    }

                    Repeater {
                        model: bar.calendarCells

                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredWidth: modelData.week !== undefined ? 36 : 44
                            Layout.preferredHeight: 30
                            radius: 6
                            color: "transparent"
                            // Today is outlined, not filled
                            border.width: modelData.today ? 1 : 0
                            border.color: bar.accent

                            BarText {
                                anchors.centerIn: parent
                                text: modelData.week ?? modelData.day
                                font.pixelSize: modelData.week !== undefined ? 10 : 13
                                font.bold: modelData.today ?? false
                                color: modelData.week !== undefined ? Qt.darker(bar.fg, 1.9)
                                    : !modelData.inMonth ? Qt.darker(bar.fg, 2.2)
                                    : modelData.weekend ? Qt.darker(bar.fg, 1.45) : bar.fg
                            }
                        }
                    }
                }

                // Month stepping
                RowLayout {
                    Layout.fillWidth: true

                    Chevron {
                        text: "󰅁"
                        step: -1
                    }

                    Caption {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(bar.calendarView, "MMMM yyyy").toUpperCase()
                        font.pixelSize: 12
                    }

                    Chevron {
                        text: "󰅂"
                        step: 1
                    }
                }
            }
        }
    }

    // Clicking anywhere else closes the calendar (the bar is included so the clock can toggle it).
    // Grabs start once their popup is actually shown: one started along with it misses the
    // popup's surface, and the first click inside then counts as outside.
    HyprlandFocusGrab {
        windows: [calendarPanel, bar]
        active: calendarPanel.backingWindowVisible
        onCleared: bar.calendarOpen = false
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
            bar.toggleWeather();
        }

        BarText {
            id: weatherText
            anchors.centerIn: parent
            text: bar.weather ? `${bar.weather.icon} ${bar.weather.temp}°C` : ""
        }
    }

    // ---- Mail and Teams, right of the weather (of the clock while there's no weather)

    RowLayout {
        anchors {
            left: weatherButton.visible ? weatherButton.right : clockArea.right
            leftMargin: 12
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 12

        // Mail: left click shows or hides Thunderbird (SUPER + M); highlighted on new mail
        MouseArea {
            readonly property string tip: bar.messaging.mailNew ? "Mail · new messages" : "Mail"

            implicitWidth: mailIcon.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onTipChanged: if (containsMouse) bar.showTooltip(this, tip)
            onClicked: {
                bar.hideTooltip(this);
                bar.messaging.show("mail", true);
            }

            BarText {
                id: mailIcon
                anchors.centerIn: parent
                text: bar.messaging.mailNew ? "󰇮" : "󰇰"
                color: bar.messaging.mailNew ? bar.warning : bar.fg
            }
        }

        // Teams: left click shows or hides it (SUPER + Y), right click toggles call mode
        // (SUPER + SHIFT + Y); unread count from its window title
        MouseArea {
            readonly property int unread: bar.messaging.teamsUnread
            readonly property bool alert: unread > 0 || bar.messaging.teamsNew
            readonly property string tip: unread > 0 ? `Teams · ${unread} unread` : bar.messaging.teamsNew ? "Teams · new messages" : "Teams"

            implicitWidth: teamsIcon.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onTipChanged: if (containsMouse) bar.showTooltip(this, tip)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                bar.hideTooltip(this);
                if (mouse.button === Qt.RightButton)
                    bar.messaging.toggleTeamsCall();
                else
                    bar.messaging.show("teams", true);
            }

            BarText {
                id: teamsIcon
                anchors.centerIn: parent
                text: parent.unread > 0 ? `󰊻 ${parent.unread}` : "󰊻"
                color: parent.alert ? bar.warning : bar.fg
            }
        }
    }

    function toggleWeather() {
        const open = !weatherOpen;
        closePanels();
        weatherOpen = open;
    }

    // Calendar month stepping
    component Chevron: BarText {
        id: chevron
        property int step
        font.pixelSize: 16
        color: chevronArea.containsMouse ? bar.accent : Qt.darker(bar.fg, 1.4)

        MouseArea {
            id: chevronArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.moveCalendar(chevron.step)
        }
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
            Keys.onPressed: event => bar.panelKey(event)

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
        active: weatherPanel.backingWindowVisible
        onCleared: bar.weatherOpen = false
    }

    // ---- Audio (PipeWire): the default output's volume, and apps recording

    readonly property PwNode sink: Pipewire.defaultAudioSink
    // Capture streams: an app has a microphone (or another source) open
    readonly property var recorders: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream)

    function volumeIcon(node) {
        const audio = node?.audio;
        if (!audio || audio.muted)
            return "󰝟";
        return audio.volume >= 0.67 ? "󰕾" : audio.volume >= 0.34 ? "󰖀" : "󰕿";
    }

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // Volume, mute and stream properties are only valid on bound nodes
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource, ...bar.recorders]
    }

    AudioPanel {
        id: audioPanel
        bar: bar
        button: volumeButton
    }

    // ---- Network (NetworkManager): wired when plugged in, else the Wi-Fi network

    readonly property var netDevices: Networking.devices.values
    readonly property var wiredUp: netDevices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: netDevices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    function wifiIcon(strength) {
        return ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(strength * 5))];
    }

    NetworkPanel {
        id: networkPanel
        bar: bar
        button: netButton
    }

    // ---- Bluetooth (BlueZ), hidden without an adapter

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btConnected: btAdapter?.devices.values.filter(d => d.connected) ?? []

    BluetoothPanel {
        id: bluetoothPanel
        bar: bar
        button: btButton
    }

    // ---- Tailscale, hidden without tailscaled

    TailscalePanel {
        id: tailscalePanel
        bar: bar
        button: tsButton
        tailscale: bar.tailscale
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
            Keys.onPressed: event => bar.panelKey(event)

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
                        onActivated: {
                            bar.messaging.reveal(modelData);
                            bar.notifications.forget(modelData.key);
                        }
                        onCloseRequested: bar.notifications.forget(modelData.key)
                    }
                }
            }
        }
    }

    // Clicking anywhere else closes the history (the bar is included so the bell can toggle it)
    HyprlandFocusGrab {
        windows: [historyPanel, bar]
        active: historyPanel.backingWindowVisible
        onCleared: bar.notifications.historyOpen = false
    }

    // ---- Keyboard layout selector, dropping down from the layout indicator

    property bool layoutOpen: false
    property int layoutCursor: 0 // row highlighted for the keyboard

    function toggleLayouts() {
        const open = !layoutOpen;
        closePanels();
        layoutOpen = open;
        if (open)
            layoutCursor = keyboard.index;
    }

    function selectLayout(i) {
        keyboard.select(i);
        layoutOpen = false;
    }

    PopupWindow {
        id: layoutPanel
        visible: bar.layoutOpen
        color: "transparent"
        implicitWidth: layoutColumn.implicitWidth + 12
        implicitHeight: layoutColumn.implicitHeight + 18

        // Centered under the indicator
        anchor {
            id: layoutAnchor
            window: bar
            adjustment: PopupAdjustment.Slide
            rect.width: 1
            rect.height: 1
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            onAnchoring: {
                const p = bar.contentItem.mapFromItem(layoutButton, layoutButton.width / 2 - layoutPanel.implicitWidth / 2, 0);
                layoutAnchor.rect.x = Math.round(p.x);
                layoutAnchor.rect.y = bar.height;
            }
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
            Keys.onPressed: event => bar.panelKey(event)

            ColumnLayout {
                id: layoutColumn
                anchors {
                    fill: parent
                    margins: 6
                }
                spacing: 2

                Repeater {
                    model: bar.keyboard.layouts.length

                    delegate: Rectangle {
                        id: layoutRow
                        required property int index
                        readonly property bool current: index === bar.keyboard.index

                        Layout.fillWidth: true
                        implicitWidth: layoutRowText.implicitWidth + 24
                        implicitHeight: layoutRowText.implicitHeight + 10
                        radius: 6
                        color: layoutRowArea.containsMouse || index === bar.layoutCursor ? bar.muted : "transparent"

                        BarText {
                            id: layoutRowText
                            anchors {
                                left: parent.left
                                leftMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            text: `${bar.keyboard.codeOf(layoutRow.index)}  ${bar.keyboard.nameOf(layoutRow.index)}`
                            color: layoutRow.current ? bar.accent : bar.fg
                            font.bold: layoutRow.current
                        }

                        MouseArea {
                            id: layoutRowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) bar.layoutCursor = layoutRow.index
                            onClicked: bar.selectLayout(layoutRow.index)
                        }
                    }
                }
            }
        }
    }

    // Clicking anywhere else closes the selector
    HyprlandFocusGrab {
        windows: [layoutPanel, bar]
        active: layoutPanel.backingWindowVisible
        onCleared: bar.layoutOpen = false
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

        // Pending package updates (Updates.qml), shown only when there are some: click installs them
        MouseArea {
            readonly property string tip: `${bar.updates.count} update${bar.updates.count === 1 ? "" : "s"}`
                + (bar.updates.aurCount > 0 ? ` (${bar.updates.aurCount} from the AUR)` : "") + " · click to install"

            visible: bar.updates.count > 0
            implicitWidth: updatesText.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onTipChanged: if (containsMouse) bar.showTooltip(this, tip)
            onClicked: {
                bar.hideTooltip(this);
                bar.updates.install();
            }

            BarText {
                id: updatesText
                anchors.centerIn: parent
                text: `󰚰 ${bar.updates.count}`
            }
        }

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

        // Keyboard layout: left click opens the selector, right click (or CTRL + ALT + SPACE) picks the next one
        MouseArea {
            id: layoutButton
            implicitWidth: layoutText.implicitWidth
            Layout.fillHeight: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse && !bar.layoutOpen ? bar.showTooltip(this, bar.keyboard.name) : bar.hideTooltip(this)
            onClicked: mouse => {
                bar.hideTooltip(this);
                if (mouse.button === Qt.RightButton)
                    bar.keyboard.next();
                else
                    bar.toggleLayouts();
            }

            BarText {
                id: layoutText
                anchors.centerIn: parent
                text: bar.keyboard.code
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

        // Microphone in use: shown only while an app records, crossed out if the input is muted
        MouseArea {
            readonly property bool micMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false
            readonly property string tip: {
                const apps = [...new Set(bar.recorders.map(n => n.properties["application.name"] || n.name))];
                return `${micMuted ? "Muted, but recorded by" : "Recording"}: ${apps.join(", ")}`;
            }

            visible: bar.recorders.length > 0
            implicitWidth: micIcon.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onTipChanged: if (containsMouse) bar.showTooltip(this, tip)
            onClicked: {
                bar.hideTooltip(this);
                bar.toggleAudio();
            }

            BarText {
                id: micIcon
                anchors.centerIn: parent
                text: parent.micMuted ? "󰍭" : "󰍬"
                color: parent.micMuted ? bar.muted : bar.urgent
            }
        }

        // Volume: left click opens the mixer, right click mutes, scroll changes the volume
        MouseArea {
            id: volumeButton
            readonly property string tip: bar.sink?.audio
                ? `${bar.sink.description || bar.sink.name}: ${bar.sink.audio.muted ? "muted" : Math.round(bar.sink.audio.volume * 100) + "%"}`
                : "No output device"

            implicitWidth: volumeIcon.implicitWidth
            Layout.fillHeight: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse && !audioPanel.open ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onTipChanged: if (containsMouse && !audioPanel.open) bar.showTooltip(this, tip)
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (bar.sink?.audio)
                        bar.sink.audio.muted = !bar.sink.audio.muted;
                    return;
                }
                bar.hideTooltip(this);
                bar.toggleAudio();
            }
            onWheel: wheel => bar.setVolume((bar.sink?.audio?.volume ?? 0) + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))

            BarText {
                id: volumeIcon
                anchors.centerIn: parent
                text: bar.volumeIcon(bar.sink)
            }
        }

        // Bluetooth: left click opens the device list, right click turns it on or off
        MouseArea {
            id: btButton
            readonly property string tip: !bar.btAdapter?.enabled ? "Bluetooth off"
                : bar.btConnected.length > 0 ? bar.btConnected.map(d => d.name).join(", ") : "Bluetooth on"

            visible: bar.btAdapter !== null
            implicitWidth: btIcon.implicitWidth
            Layout.fillHeight: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse && !bluetoothPanel.open ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onTipChanged: if (containsMouse && !bluetoothPanel.open) bar.showTooltip(this, tip)
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    bar.btAdapter.enabled = !bar.btAdapter.enabled;
                    return;
                }
                bar.hideTooltip(this);
                bar.toggleBluetooth();
            }

            BarText {
                id: btIcon
                anchors.centerIn: parent
                text: !bar.btAdapter?.enabled ? "󰂲" : bar.btConnected.length > 0 ? "󰂱" : "󰂯"
                color: bar.btAdapter?.enabled ? bar.fg : bar.muted
            }
        }

        // Tailscale: left click opens the devices, right click connects or disconnects
        MouseArea {
            id: tsButton
            readonly property var ts: bar.tailscale
            readonly property string tip: ts.running
                ? `Tailscale · ${ts.ipv4Of(ts.self)}` + (ts.exitNode ? ` · exit node ${ts.nameOf(ts.exitNode)}` : "")
                : ts.backendState === "NeedsLogin" ? "Tailscale logged out" : "Tailscale off"

            visible: ts.available
            implicitWidth: tsIcon.implicitWidth
            Layout.fillHeight: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse && !tailscalePanel.open ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onTipChanged: if (containsMouse && !tailscalePanel.open) bar.showTooltip(this, tip)
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (ts.running || ts.backendState === "Stopped")
                        ts.setRunning(!ts.running);
                    return;
                }
                bar.hideTooltip(this);
                bar.toggleTailscale();
            }

            BarText {
                id: tsIcon
                anchors.centerIn: parent
                text: "󰖂"
                color: !parent.ts.running ? bar.muted : parent.ts.exitNode ? bar.accent : bar.fg
            }
        }

        // Network: left click opens Wi-Fi and wired connections
        MouseArea {
            id: netButton
            readonly property string tip: bar.wiredUp ? `Ethernet · ${bar.wiredUp.name}`
                : bar.wifiNetwork ? `${bar.wifiNetwork.name} (${Math.round(bar.wifiNetwork.signalStrength * 100)}%)`
                : "Disconnected"

            implicitWidth: netIcon.implicitWidth
            Layout.fillHeight: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse && !networkPanel.open ? bar.showTooltip(this, tip) : bar.hideTooltip(this)
            onClicked: {
                bar.hideTooltip(this);
                bar.toggleNetwork();
            }

            BarText {
                id: netIcon
                anchors.centerIn: parent
                text: bar.wiredUp ? "󰈀" : bar.wifiNetwork ? bar.wifiIcon(bar.wifiNetwork.signalStrength) : bar.wifiDevice ? "󰤮" : "󰈂"
                color: bar.wiredUp || bar.wifiNetwork ? bar.fg : bar.muted
            }
        }

        // Appearance: left click switches light/dark (darkman, which otherwise follows
        // sunrise and sunset), right click toggles the night light
        MouseArea {
            implicitWidth: themeIcon.implicitWidth
            Layout.fillHeight: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, Theme.dark ? "Dark mode" : "Light mode") : bar.hideTooltip(this)
            onClicked: mouse => {
                bar.hideTooltip(this);
                // Straight to scripts/theme if darkman isn't running (it starts with Hyprland)
                if (mouse.button === Qt.LeftButton)
                    Quickshell.execDetached(["sh", "-c", `darkman toggle || ~/.config/hypr/scripts/theme ${Theme.dark ? "light" : "dark"}`]);
                else
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/nightlight"]);
            }

            BarText {
                id: themeIcon
                anchors.centerIn: parent
                text: Theme.dark ? "󰖔" : "󰖙"
            }
        }

        // Bell: left click opens the history, right click toggles do-not-disturb
        MouseArea {
            id: bell
            implicitWidth: dndIcon.implicitWidth
            Layout.fillHeight: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: containsMouse ? bar.showTooltip(this, bar.notifications.dnd ? "Notifications silenced" : "Notifications on") : bar.hideTooltip(this)
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    bar.hideTooltip(this);
                    const open = !bar.notifications.historyOpen;
                    bar.closePanels();
                    bar.notifications.historyOpen = open;
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
    }
}
