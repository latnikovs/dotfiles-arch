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
-- custom mode. The presets are in utm-vm.display-modes: the bar's display panel picks one, SUPER + ALT + /
-- steps through them (scripts/monitor-mode), and the choice is applied after this file.
hl.monitor({
    output   = "Virtual-1",
    mode     = "2560x1440@60",
    position = "auto",
    scale    = 1,
})
hl.bind("SUPER + ALT + SLASH", hl.dsp.exec_cmd("~/.config/hypr/scripts/monitor-mode next Virtual-1"),
    { description = "VM display: next mode (Dell / MacBook)" })

-- macOS swallows Cmd + Esc (system menu) and Cmd + Option + Space (menu, Finder search there)
-- before they reach the VM, so open the menu on SUPER + ALT + M too; System is in it.
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/menu"), { description = "Menu (commands, as Omarchy's)" })
