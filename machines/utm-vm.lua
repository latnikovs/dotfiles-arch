-- Per-machine overrides for the UTM VM. Installed as ~/.config/hypr/local.lua by: ./install.sh utm-vm

-- virgl here only exposes GLES, and kitty needs desktop OpenGL 3.1,
-- so run kitty with Mesa's software renderer.
local kitty = hl.dsp.exec_cmd("env LIBGL_ALWAYS_SOFTWARE=1 kitty")
for _, key in ipairs({ "SUPER + Q", "SUPER + RETURN" }) do
    hl.unbind(key)
    hl.bind(key, kitty, { description = "Terminal" })
end

-- UTM's virtual display defaults to 1280x800; 2560x1440 isn't advertised, so Hyprland generates a custom mode.
hl.monitor({
    output   = "Virtual-1",
    mode     = "2560x1440@60",
    position = "auto",
    scale    = 1,
})
