-- Per-machine overrides for the UTM VM. Installed as ~/.config/hypr/local.lua by: ./install.sh utm-vm

-- virgl here only exposes GLES, and kitty needs desktop OpenGL 3.1,
-- so run kitty with Mesa's software renderer.
local kitty = hl.dsp.exec_cmd("env LIBGL_ALWAYS_SOFTWARE=1 kitty")
for _, key in ipairs({ "SUPER + Q", "SUPER + RETURN" }) do
    hl.unbind(key)
    hl.bind(key, kitty)
end

-- Dell P2721Q (4K) with macOS at "Default" and UTM in Retina mode, so each VM pixel is one
-- physical pixel. 1.5 gives a 2560x1440 workspace. 4K isn't advertised by UTM, so Hyprland
-- generates a custom mode.
hl.monitor({
    output   = "Virtual-1",
    mode     = "3840x2160@60",
    position = "auto",
    scale    = 1.5,
})
