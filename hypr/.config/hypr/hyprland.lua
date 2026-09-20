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
local fileManager = "dolphin"
local browser     = "chromium"
local menu        = "pkill -x wofi || wofi"


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
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
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

        col = {
            active_border   = "rgb(88c0d0)", -- Nord frost
            inactive_border = "rgb(4c566a)",
        },

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
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
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

-- Every bind gets a description: SUPER + K lists them (scripts/keybindings)
local function bind(keys, description, dispatcher, opts)
    opts = opts or {}
    opts.description = description
    return hl.bind(keys, dispatcher, opts)
end

bind(mainMod .. " + K", "Show keybindings", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybindings"))

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
bind(mainMod .. " + Q", "Terminal", hl.dsp.exec_cmd(terminal))
bind(mainMod .. " + RETURN", "Terminal", hl.dsp.exec_cmd(terminal))
local closeWindowBind = bind(mainMod .. " + W", "Close window", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
bind(mainMod .. " + M", "Exit Hyprland", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
bind(mainMod .. " + E", "File manager", hl.dsp.exec_cmd(fileManager))
bind(mainMod .. " + B", "Browser", hl.dsp.exec_cmd(browser))
bind(mainMod .. " + T", "Toggle window floating", hl.dsp.window.float({ action = "toggle" }))
bind(mainMod .. " + R", "App launcher", hl.dsp.exec_cmd(menu))
bind(mainMod .. " + SPACE", "App launcher", hl.dsp.exec_cmd(menu))
bind(mainMod .. " + F", "Fullscreen", hl.dsp.window.fullscreen())
bind(mainMod .. " + CTRL + SPACE", "Next wallpaper", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper next"))

-- Screenshots; SUPER + CTRL variants for keyboards without a Print key (e.g. Mac)
local screenshot = "~/.config/hypr/scripts/screenshot"
bind("Print",                         "Screenshot region", hl.dsp.exec_cmd(screenshot .. " region"))
bind("SHIFT + Print",                 "Screenshot monitor", hl.dsp.exec_cmd(screenshot .. " output"))
bind(mainMod .. " + CTRL + S",         "Screenshot region", hl.dsp.exec_cmd(screenshot .. " region"))
bind(mainMod .. " + CTRL + SHIFT + S", "Screenshot monitor", hl.dsp.exec_cmd(screenshot .. " output"))

-- Notifications (quickshell), same keys as Omarchy
local notifications = "quickshell ipc call notifications "
bind(mainMod .. " + comma",         "Dismiss notification", hl.dsp.exec_cmd(notifications .. "dismissOne"))
bind(mainMod .. " + SHIFT + comma", "Dismiss all notifications", hl.dsp.exec_cmd(notifications .. "dismissAll"))
bind(mainMod .. " + ALT + comma",   "Open last notification", hl.dsp.exec_cmd(notifications .. "invokeLast"))
bind(mainMod .. " + CTRL + comma",  "Toggle do not disturb", hl.dsp.exec_cmd("~/.config/hypr/scripts/notifications-dnd"))
bind(mainMod .. " + SHIFT + ALT + comma", "Notification history", hl.dsp.exec_cmd(notifications .. "toggleHistory"))

-- Bar dropdowns (quickshell): calendar as in Omarchy; weather is the dropdown here, not Omarchy's notification
local bar = "quickshell ipc call bar "
bind(mainMod .. " + CTRL + ALT + D", "Calendar", hl.dsp.exec_cmd(bar .. "toggleCalendar"))
bind(mainMod .. " + CTRL + ALT + W", "Weather", hl.dsp.exec_cmd(bar .. "toggleWeather"))

bind(mainMod .. " + P", "Toggle window pseudotiling", hl.dsp.window.pseudo())
bind(mainMod .. " + J", "Toggle window split", hl.dsp.layout("togglesplit"))    -- dwindle only

-- Move focus with mainMod + arrow keys
bind(mainMod .. " + left",  "Focus window left", hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + right", "Focus window right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. " + up",    "Focus window up", hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + down",  "Focus window down", hl.dsp.focus({ direction = "down" }))

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
bind(mainMod .. " + S",             "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
bind(mainMod .. " + ALT + S",       "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
bind(mainMod .. " + grave",         "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
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

-- Terminals (kitty, and kitty under our own classes like org.dotfiles.agent), for the clipboard binds
hl.window_rule({
    name  = "tag-terminals",
    match = { class = "(kitty|org\\.dotfiles\\..*)" },

    tag   = "+terminal",
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
