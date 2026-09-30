-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "~/.config/hypr/scripts/files"
local browser     = "chromium"
local menu        = "pkill -x fuzzel || fuzzel"
local passwords   = "special:passwords"
local music       = "special:music"
local mail        = "special:mail"
local notes       = "special:notes"
local teams       = "special:teams"
-- Teams as a Chromium app window; Microsoft has no Linux client
local teamsApp    = browser .. " --app=https://teams.microsoft.com/"


------------------------
---- LIGHT AND DARK ----
------------------------

-- Nord window borders for dark or light mode. scripts/theme (run by darkman at sunrise
-- and sunset, or by the bar's sun/moon button) calls this with `hyprctl eval`; at
-- startup it follows the color-scheme setting that script last set.
local borders = {
    dark  = { active = "rgb(88c0d0)", inactive = "rgb(4c566a)" }, -- Nord frost, polar night
    light = { active = "rgb(5e81ac)", inactive = "rgb(c8ced9)" }, -- deeper frost, snow storm
}

function applyTheme(mode)
    local b = borders[mode] or borders.dark
    hl.config({ general = { col = { active_border = b.active, inactive_border = b.inactive } } })
end

local scheme = io.popen("gsettings get org.gnome.desktop.interface color-scheme")
applyTheme(scheme and scheme:read("*l") == "'prefer-light'" and "light" or "dark")
if scheme then scheme:close() end


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- hl.on("hyprland.start", function () 
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)

hl.on("hyprland.start", function ()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper init; hyprpaper")
    -- Clipboard history for SUPER + CTRL + V (scripts/clipboard-history)
    hl.exec_cmd("wl-paste --type text --watch ~/.config/hypr/scripts/clipboard-store")
    hl.exec_cmd("wl-paste --type image --watch ~/.config/hypr/scripts/clipboard-store")
    -- Locks after 5 idle minutes and before suspend (hypridle.conf)
    hl.exec_cmd("hypridle")
    -- Night light on a schedule (hyprsunset.conf); SUPER + CTRL + N toggles it
    hl.exec_cmd("hyprsunset")
    -- Light or dark by sunrise and sunset (darkman runs scripts/theme)
    hl.exec_cmd("darkman run")
    -- Running (locked) from login, so KeePassXC-Browser always has something to talk to
    hl.exec_cmd("[workspace " .. passwords .. " silent] keepassxc")
    -- Mail and Teams only notify while running, so they start hidden too
    hl.exec_cmd("[workspace " .. mail .. " silent] thunderbird")
    hl.exec_cmd(teamsApp)
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 6,

        border_size = 2,

        -- Border colours: applyTheme() below, light or dark

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,     -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true,  -- If true disables the random hyprland logo / anime girl background. :(
        -- If hyprlock crashes the screen stays locked; this lets a new one take over (scripts/lock now)
        allow_session_lock_restore = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        -- English, Latvian, Russian; CTRL + ALT + SPACE cycles them, and Quickshell remembers
        -- the layout per window (Keyboard.qml). Binds always use the first layout.
        -- Latvian "apostrophe", as on macOS: ' then a letter types ā č ē ģ ī ķ ļ ņ š ū ž,
        -- ' then space (or ' twice) types '.
        kb_layout  = "us,lv,ru",
        kb_variant = ",apostrophe,",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        -- Faster key repeat than the defaults (25/s after 600ms)
        repeat_rate  = 40,
        repeat_delay = 200,

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Every bind gets a description: SUPER + / lists them (scripts/keybindings)
local function bind(keys, description, dispatcher, opts)
    opts = opts or {}
    opts.description = description
    return hl.bind(keys, dispatcher, opts)
end

-- Every special workspace shares one animation, and it's read as the toggle starts,
-- so each toggle sets its own first. For slides the style names the edge the offset
-- is measured from: "slide top" drops in from above, "slide bottom" retracts back up.
local function toggleSpecial(name, show, hide)
    return function()
        hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 3, bezier = "easeOutQuint",   style = show })
        hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "easeInOutCubic", style = hide })
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
    end
end

bind(mainMod .. " + SLASH", "Show keybindings", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybindings"))

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
bind(mainMod .. " + Q", "Terminal", hl.dsp.exec_cmd(terminal))
bind(mainMod .. " + RETURN", "Terminal", hl.dsp.exec_cmd(terminal))
local closeWindowBind = bind(mainMod .. " + W", "Close window", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
bind(mainMod .. " + ESCAPE", "System menu", hl.dsp.exec_cmd("~/.config/hypr/scripts/system menu"))
bind(mainMod .. " + CTRL + L", "Lock", hl.dsp.exec_cmd("~/.config/hypr/scripts/lock"))
bind(mainMod .. " + CTRL + N", "Toggle night light", hl.dsp.exec_cmd("~/.config/hypr/scripts/nightlight"))
bind(mainMod .. " + B", "Browser", hl.dsp.exec_cmd(browser))
bind(mainMod .. " + SHIFT + B", "Brave Origin", hl.dsp.exec_cmd("brave-origin"))
-- File manager (Nautilus). Omarchy's keys swapped: the plain one opens in the focused
-- terminal's directory (home for any other window), the Alt one always opens home.
bind(mainMod .. " + SHIFT + F",       "File manager (cwd)", hl.dsp.exec_cmd(fileManager .. " cwd"))
bind(mainMod .. " + ALT + SHIFT + F", "File manager", hl.dsp.exec_cmd(fileManager))
bind(mainMod .. " + SHIFT + SLASH", "Toggle passwords", toggleSpecial("passwords", "fade", "fade"))
bind(mainMod .. " + SHIFT + M", "Toggle music", toggleSpecial("music", "fade", "fade"))
bind(mainMod .. " + M", "Toggle mail", toggleSpecial("mail", "fade", "fade"))
bind(mainMod .. " + N", "Toggle notes", toggleSpecial("notes", "fade", "fade"))

-- Teams call mode (SUPER + SHIFT + Y): Teams leaves its special workspace for a small
-- floating window in the top right corner, pinned so it stays in view on every workspace
-- while you share another window. Pressed again, it goes back. Global for Quickshell
-- (right click on the bar's Teams icon): `hyprctl eval 'toggleTeamsCall()'`.
local teamsWindow = "class:^chrome-teams\\..*$"

local function teamsInCall()
    local window = hl.get_window(teamsWindow)
    return window and window.pinned and window or nil
end

function toggleTeamsCall()
    local window = hl.get_window(teamsWindow)
    if not window then
        return
    end
    local target = "address:" .. window.address
    if window.pinned then
        hl.dispatch(hl.dsp.window.pin({ action = "disable", window = target }))
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = target }))
        hl.dispatch(hl.dsp.window.move({ workspace = teams, follow = false, window = target }))
        return
    end
    -- Close Teams' workspace if it's showing: emptied, it would stay open over
    -- everything, dimming the other windows and taking the clicks
    local active = hl.get_active_special_workspace()
    if active and active.name == teams then
        toggleSpecial("teams", "fade", "fade")()
    end
    -- Sizes in layout coordinates, so scaled monitors come out the same; below the bar (26px)
    local monitor = hl.get_active_monitor()
    local gap = 6
    local width = math.floor(monitor.width / monitor.scale * 0.3)
    local height = math.floor(width * 0.65)
    hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace().id, follow = false, window = target }))
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = target }))
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = target }))
    hl.dispatch(hl.dsp.window.move({
        x = monitor.x + math.floor(monitor.width / monitor.scale) - width - gap,
        y = monitor.y + 26 + gap,
        window = target,
    }))
    hl.dispatch(hl.dsp.window.pin({ action = "enable", window = target }))
end

-- For Quickshell's mail and Teams buttons and notification clicks, through
-- `hyprctl eval 'showSpecial("mail")'`: brings the workspace up, or with toggle
-- also hides it when it's already showing. In call mode Teams has left its
-- workspace (which would start a second Teams), so focus goes to it instead, and
-- from it back to the window you came from.
local beforeTeams = nil

function showSpecial(name, toggle)
    local call = name == "teams" and teamsInCall()
    if call then
        local current = hl.get_active_window()
        if current and current.address == call.address then
            if beforeTeams and hl.get_window("address:" .. beforeTeams) then
                hl.dispatch(hl.dsp.focus({ window = "address:" .. beforeTeams }))
            end
        else
            beforeTeams = current and current.address or nil
            hl.dispatch(hl.dsp.focus({ window = "address:" .. call.address }))
        end
        return
    end
    local active = hl.get_active_special_workspace()
    if active and active.name == "special:" .. name and not toggle then
        return
    end
    toggleSpecial(name, "fade", "fade")()
end

bind(mainMod .. " + Y", "Toggle Teams (in call mode: focus it / go back)", function() showSpecial("teams", true) end)
bind(mainMod .. " + SHIFT + Y", "Teams call mode (pinned, top right)", toggleTeamsCall)

bind(mainMod .. " + T", "Toggle window floating", hl.dsp.window.float({ action = "toggle" }))
bind(mainMod .. " + R", "App launcher", hl.dsp.exec_cmd(menu))
bind(mainMod .. " + SPACE", "App launcher", hl.dsp.exec_cmd(menu))
bind(mainMod .. " + F", "Fullscreen", hl.dsp.window.fullscreen())
bind(mainMod .. " + CTRL + SPACE", "Next wallpaper", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper next"))
bind("CTRL + ALT + SPACE", "Next keyboard layout", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

-- Screenshots; SUPER + CTRL variants for keyboards without a Print key (e.g. Mac)
local screenshot = "~/.config/hypr/scripts/screenshot"
bind("Print",                         "Screenshot region, annotate", hl.dsp.exec_cmd(screenshot .. " annotate"))
bind("ALT + Print",                   "Screenshot region", hl.dsp.exec_cmd(screenshot .. " region"))
bind("SHIFT + Print",                 "Screenshot monitor", hl.dsp.exec_cmd(screenshot .. " output"))
bind(mainMod .. " + CTRL + S",         "Screenshot region, annotate", hl.dsp.exec_cmd(screenshot .. " annotate"))
bind(mainMod .. " + CTRL + ALT + S",   "Screenshot region", hl.dsp.exec_cmd(screenshot .. " region"))
bind(mainMod .. " + CTRL + SHIFT + S", "Screenshot monitor", hl.dsp.exec_cmd(screenshot .. " output"))

-- Notifications (quickshell), same keys as Omarchy
local notifications = "quickshell ipc call notifications "
bind(mainMod .. " + comma",         "Dismiss notification", hl.dsp.exec_cmd(notifications .. "dismissOne"))
bind(mainMod .. " + SHIFT + comma", "Dismiss all notifications", hl.dsp.exec_cmd(notifications .. "dismissAll"))
bind(mainMod .. " + ALT + comma",   "Open last notification", hl.dsp.exec_cmd(notifications .. "invokeLast"))
bind(mainMod .. " + CTRL + comma",  "Toggle do not disturb", hl.dsp.exec_cmd("~/.config/hypr/scripts/notifications-dnd"))
bind(mainMod .. " + SHIFT + ALT + comma", "Notification history", hl.dsp.exec_cmd(notifications .. "toggleHistory"))

-- Bar dropdowns (quickshell): calendar, audio, Wi-Fi and Bluetooth on Omarchy's keys; weather is the dropdown here, not Omarchy's notification
local bar = "quickshell ipc call bar "
bind(mainMod .. " + CTRL + ALT + D", "Calendar", hl.dsp.exec_cmd(bar .. "toggleCalendar"))
bind(mainMod .. " + CTRL + ALT + W", "Weather", hl.dsp.exec_cmd(bar .. "toggleWeather"))
bind(mainMod .. " + CTRL + A",       "Audio", hl.dsp.exec_cmd(bar .. "toggleAudio"))
bind(mainMod .. " + CTRL + W",       "Network", hl.dsp.exec_cmd(bar .. "toggleNetwork"))
bind(mainMod .. " + CTRL + B",       "Bluetooth", hl.dsp.exec_cmd(bar .. "toggleBluetooth"))
bind(mainMod .. " + CTRL + T",       "Tailscale", hl.dsp.exec_cmd(bar .. "toggleTailscale"))

-- Reminders (scripts/remind, listed and fired by the bar), on Omarchy's keys
bind(mainMod .. " + CTRL + R",       "New reminder", hl.dsp.exec_cmd("~/.config/hypr/scripts/remind"))
bind(mainMod .. " + CTRL + ALT + R", "Reminders", hl.dsp.exec_cmd(bar .. "toggleReminders"))
bind(mainMod .. " + CTRL + SHIFT + R", "Clear reminders", hl.dsp.exec_cmd("~/.config/hypr/scripts/remind clear"))

bind(mainMod .. " + P", "Toggle window pseudotiling", hl.dsp.window.pseudo())
bind(mainMod .. " + backslash", "Toggle window split", hl.dsp.layout("togglesplit"))    -- dwindle only

-- Move focus with mainMod + arrow keys or vim keys
bind(mainMod .. " + left",  "Focus window left", hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + right", "Focus window right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. " + up",    "Focus window up", hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + down",  "Focus window down", hl.dsp.focus({ direction = "down" }))
bind(mainMod .. " + H", "Focus window left", hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + L", "Focus window right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. " + K", "Focus window up", hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + J", "Focus window down", hl.dsp.focus({ direction = "down" }))

-- Swap window with its neighbour with mainMod + SHIFT + arrow keys or vim keys
bind(mainMod .. " + SHIFT + left",  "Swap window left", hl.dsp.window.swap({ direction = "left" }))
bind(mainMod .. " + SHIFT + right", "Swap window right", hl.dsp.window.swap({ direction = "right" }))
bind(mainMod .. " + SHIFT + up",    "Swap window up", hl.dsp.window.swap({ direction = "up" }))
bind(mainMod .. " + SHIFT + down",  "Swap window down", hl.dsp.window.swap({ direction = "down" }))
bind(mainMod .. " + SHIFT + H", "Swap window left", hl.dsp.window.swap({ direction = "left" }))
bind(mainMod .. " + SHIFT + L", "Swap window right", hl.dsp.window.swap({ direction = "right" }))
bind(mainMod .. " + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "up" }))
bind(mainMod .. " + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    bind(mainMod .. " + " .. key,             "Go to workspace " .. i, hl.dsp.focus({ workspace = i}))
    bind(mainMod .. " + SHIFT + " .. key,     "Move window to workspace " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Universal clipboard, as in Omarchy: SUPER (Cmd on the Mac) + C/V/X/A send the app's own
-- shortcut, CTRL + SHIFT + C/V in terminals (tagged below) so CTRL + C still interrupts.
-- Sent as separate down/up key states: send_shortcut can leave the key stuck repeating.
local function sendShortcut(mods, key)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
        hl.timer(function()
            hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
        end, { timeout = 50, type = "oneshot" })
    end
end

local function activeIsTerminal()
    local window = hl.get_active_window()
    for _, tag in ipairs(window and window.tags or {}) do
        if tag:gsub("%*$", "") == "terminal" then return true end  -- dynamic tags end in "*"
    end
    return false
end

local function clipboardShortcut(key)
    return function()
        sendShortcut(activeIsTerminal() and "CTRL SHIFT" or "CTRL", key)()
    end
end

bind(mainMod .. " + C",        "Copy", clipboardShortcut("C"))
bind(mainMod .. " + V",        "Paste", clipboardShortcut("V"))
bind(mainMod .. " + X",        "Cut", sendShortcut("CTRL", "X"))
bind(mainMod .. " + A",        "Select all", sendShortcut("CTRL", "A"))
bind(mainMod .. " + CTRL + V", "Clipboard history", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard-history"))

-- Scratchpad: a drop-down console seeded with Claude Code (qconsole.lua), same keys as Omarchy
bind(mainMod .. " + S",             "Toggle scratchpad", toggleSpecial("scratchpad", "slide top", "slide bottom"))
bind(mainMod .. " + ALT + S",       "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
bind(mainMod .. " + grave",         "Toggle scratchpad", toggleSpecial("scratchpad", "slide top", "slide bottom"))
bind(mainMod .. " + SHIFT + grave", "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Scroll through existing workspaces with mainMod + scroll
bind(mainMod .. " + mouse_down", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
bind(mainMod .. " + mouse_up",   "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", "Move window", hl.dsp.window.drag(),   { mouse = true })
bind(mainMod .. " + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
bind("XF86AudioRaiseVolume", "Volume up", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", "Volume down", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
bind("XF86AudioMute",        "Mute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
bind("XF86AudioMicMute",     "Mute microphone", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
bind("XF86MonBrightnessUp",  "Brightness up", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
bind("XF86MonBrightnessDown","Brightness down", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
bind("XF86AudioNext",  "Next track", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
bind("XF86AudioPause", "Play/pause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay",  "Play/pause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev",  "Previous track", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- The launcher and dmenus (fuzzel) are slightly see-through; blur what's behind
-- them, but not the fully transparent corners outside the rounded border
hl.layer_rule({
    name  = "blur-launcher",
    match = { namespace = "^launcher$" },

    blur         = true,
    ignore_alpha = 0.5,
})

-- Terminals (kitty, and kitty under our own classes like org.dotfiles.agent), for the clipboard binds
hl.window_rule({
    name  = "tag-terminals",
    match = { class = "(kitty|org\\.dotfiles\\..*)" },

    tag   = "+terminal",
})

-- Password manager floats and stays out of screen shares, as in Omarchy
hl.window_rule({
    name  = "float-keepassxc",
    match = { class = "^KeePassXC$" },

    float           = true,
    center          = true,
    no_screen_share = true,
})

-- KeePassXC lives on its own special workspace (SUPER + SHIFT + /); opened empty,
-- because it was closed, the workspace starts it again. Only launches are pinned
-- there, so dialogs raised from the browser (unlock) appear where you are.
hl.workspace_rule({
    workspace        = passwords,
    on_created_empty = "keepassxc",
})

-- Toggling a special workspace leaves focus behind, so typing would go to the
-- window underneath. A freshly relaunched app takes focus as it maps.
local specialApps = {
    [passwords] = "class:^KeePassXC$",
    [music]     = "class:^org\\.dotfiles\\.music$",
    [mail]      = "class:^(org\\.mozilla\\.Thunderbird|thunderbird)$",
    [notes]     = "class:^org\\.dotfiles\\.notes$",
    [teams]     = teamsWindow,
}
hl.on("workspace.special_active", function(ws)
    local window = ws and specialApps[ws.name]
    if window then
        hl.dispatch(hl.dsp.focus({ window = window }))
    end
end)

-- Size only the main window; its dialogs (unlock, browser access) keep their own.
-- It opens as "KeePassXC", or "<file>.kdbx [Locked] - KeePassXC" once a database is remembered.
hl.window_rule({
    name  = "size-keepassxc",
    match = { class = "^KeePassXC$", initial_title = "^(KeePassXC|.* \\[Locked\\] - KeePassXC)$" },

    size  = { 1200, 800 },
})

-- The music player (cliamp, scripts/music) works the same way on SUPER + SHIFT + M:
-- a floating window on its own special workspace, started again when it was quit.
hl.workspace_rule({
    workspace        = music,
    on_created_empty = "~/.config/hypr/scripts/music",
})

hl.window_rule({
    name  = "float-music",
    match = { class = "^org\\.dotfiles\\.music$" },

    float  = true,
    center = true,
    size   = "monitor_w*0.6 monitor_h*0.7",
})

-- Notes (nvim on today's note, scripts/notes) the same way on SUPER + N, tiled full
-- size like mail: Obsidian's shortcut on the Mac, and like it a window that is there
-- when called, not a new one.
hl.workspace_rule({
    workspace        = notes,
    on_created_empty = "~/.config/hypr/scripts/notes",
})

-- Installing updates (the bar's update icon, scripts/updates run) in a floating terminal
hl.window_rule({
    name  = "float-updates",
    match = { class = "^org\\.dotfiles\\.updates$" },

    float  = true,
    center = true,
    size   = "monitor_w*0.6 monitor_h*0.7",
})

-- Mail (Thunderbird, SUPER + M) and Teams (SUPER + Y) get special workspaces too,
-- tiled full size. Thunderbird's launches are pinned there, so a compose window
-- opened from a mailto: link appears where you are.
hl.workspace_rule({
    workspace        = mail,
    on_created_empty = "thunderbird",
})

-- A Chromium launch hands the window to a browser that's already running, so
-- Teams is pinned by its app window class (chrome-<host>__<path>-<profile>) instead.
hl.workspace_rule({
    workspace        = teams,
    on_created_empty = teamsApp,
})

hl.window_rule({
    name  = "teams-workspace",
    match = { class = "^chrome-teams\\..*$" },

    workspace = teams .. " silent",
})

-- Nautilus, as in Omarchy: the PDF viewer floats, as do the GTK portal's pickers
-- and prompts whatever the asking app titled them, and Nautilus' own dialogs
hl.window_rule({
    name  = "float-file-previews",
    match = { class = "^(org\\.gnome\\.Papers|xdg-desktop-portal-gtk)$" },

    float  = true,
    center = true,
    size   = { 875, 600 },
})

-- Space previews (sushi) and the image viewer float too, but large: most of the monitor
hl.window_rule({
    name  = "float-large-previews",
    match = { class = "^(org\\.gnome\\.NautilusPreviewer|imv)$" },

    float  = true,
    center = true,
    size   = "monitor_w*0.7 monitor_h*0.8",
})

-- Satty (screenshot annotation) sizes itself to the image
hl.window_rule({
    name  = "float-satty",
    match = { class = "^com\\.gabm\\.satty$" },

    float  = true,
    center = true,
})

hl.window_rule({
    name  = "float-file-dialogs",
    match = {
        class = "^org\\.gnome\\.Nautilus$",
        title = "^(Open.*Files?|Open [Ff]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to (open|save).*|[Cc]hoose.*)$",
    },

    float  = true,
    center = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})


local configDir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr"

-- The scratchpad as a Quake console (SUPER + S)
dofile(configDir .. "/qconsole.lua")


---------------------------
---- PER-MACHINE LOCAL ----
---------------------------

-- Untracked overrides (monitors, scale, input, etc.) in ~/.config/hypr/local.lua.
-- Loaded last so anything set there wins. Skipped silently if the file doesn't exist.
local localConfig = configDir .. "/local.lua"
local f = io.open(localConfig, "r")
if f then
    f:close()
    dofile(localConfig)
end
