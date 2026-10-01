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

-- UTM's virtual display defaults to 1280x800; 2560x1440 isn't advertised, so Hyprland generates a custom mode.
hl.monitor({
    output   = "Virtual-1",
    mode     = "2560x1440@60",
    position = "auto",
    scale    = 1,
})

-- macOS swallows Cmd + Esc (system menu) and Cmd + Option + Space (menu, Finder search there)
-- before they reach the VM, so open the menu on SUPER + ALT + M too; System is in it.
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/menu"), { description = "Menu (commands, as Omarchy's)" })
