-- Hyprland for the login screen only: runs the Quickshell greeter (shell.qml) and
-- exits once it has handed the session to greetd. Started as the greeter user by
-- /usr/local/bin/dotfiles-greeter; install.sh puts it in /etc/greetd/.

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

hl.config({
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
    animations = {
        enabled = false,
    },
    -- The password is typed in the first layout, as on the lock screen
    input = {
        kb_layout = "us",
    },
})

-- A greeter that fails to load (or crashes) leaves a mark, so dotfiles-greeter
-- falls back to tuigreet instead of leaving a blank screen
hl.on("hyprland.start", function ()
    hl.exec_cmd("quickshell -p /etc/greetd/quickshell/shell.qml || touch \"$XDG_RUNTIME_DIR/greeter-failed\"; "
        .. "hyprctl dispatch 'hl.dsp.exit()'")
end)

-- Per-machine overrides (monitors) in /etc/greetd/local.lua, from machines/<machine>.greeter.lua
local f = io.open("/etc/greetd/local.lua", "r")
if f then
    f:close()
    dofile("/etc/greetd/local.lua")
end
