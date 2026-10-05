-- Per-machine overrides for the UTM VM. Installed as ~/.config/hypr/local.lua by: ./install.sh utm-vm

-- virgl here only exposes GLES, and kitty needs desktop OpenGL 3.1,
-- so run kitty with Mesa's software renderer. Scripts launching a terminal (scripts/agent)
-- pick it up from DOTFILES_TERMINAL.
local kittyCmd = "env LIBGL_ALWAYS_SOFTWARE=1 kitty"
hl.env("DOTFILES_TERMINAL", kittyCmd)
local kitty = hl.dsp.exec_cmd(kittyCmd)
for _, key in ipairs({ "SUPER + Q", "SUPER + RETURN" }) do
    hl.unbind(key)
    hl.bind(key, kitty, { description = "Terminal" })
end
-- The launcher starts terminal apps (htop, cliamp) in kitty too
local launcher = hl.dsp.exec_cmd("pkill -x fuzzel || fuzzel --terminal '" .. kittyCmd .. " -e'")
for _, key in ipairs({ "SUPER + SPACE", "SUPER + R" }) do
    hl.unbind(key)
    hl.bind(key, launcher, { description = "App launcher" })
end

-- UTM's virtual display defaults to 1280x800 and doesn't follow a macOS full-screen window, so the mode
-- is set to match the screen the VM is full screen on; neither is advertised, so Hyprland generates a
-- custom mode. SUPER + ALT + / switches between them, remembered in ~/.local/state/hypr/utm-vm-mode.
-- The MacBook's full-screen space stops below the notch: 3024x1890, 16:10, where 16:9 got black bars.
local vmModes = {
    "2560x1440@60", -- Dell P2721Q
    "3024x1890@60", -- MacBook Pro 14"
}
local vmModeFile = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hypr/utm-vm-mode"
local vmMode = 1
local f = io.open(vmModeFile, "r")
if f then
    local saved = f:read("l")
    f:close()
    for i, m in ipairs(vmModes) do
        if m == saved then vmMode = i end
    end
end
hl.monitor({
    output   = "Virtual-1",
    mode     = vmModes[vmMode],
    position = "auto",
    scale    = 1,
})
hl.bind("SUPER + ALT + SLASH", function()
    vmMode = vmMode % #vmModes + 1
    local m = vmModes[vmMode]
    os.execute("mkdir -p '" .. vmModeFile:match("^(.*)/") .. "'")
    local out = io.open(vmModeFile, "w")
    if out then
        out:write(m, "\n")
        out:close()
    end
    -- Keep the scale; monitor-scale then fits it to the new mode, saves the mode with it (its state
    -- is applied after this file) and shows the result
    hl.dispatch(hl.dsp.exec_cmd("s=$(~/.config/hypr/scripts/monitor-scale '' Virtual-1 2>/dev/null || echo 1); "
        .. "hyprctl eval \"hl.monitor({ output = 'Virtual-1', mode = '" .. m .. "', position = 'auto', scale = $s })\" >/dev/null; "
        .. "~/.config/hypr/scripts/monitor-scale \"$s\" Virtual-1"))
end, { description = "VM display: switch mode between the Dell and the MacBook screen" })

-- macOS swallows Cmd + Esc (system menu) and Cmd + Option + Space (menu, Finder search there)
-- before they reach the VM, so open the menu on SUPER + ALT + M too; System is in it.
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/menu"), { description = "Menu (commands, as Omarchy's)" })
