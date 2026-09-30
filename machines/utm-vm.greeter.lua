-- Per-machine overrides for the login screen on the UTM VM. Installed as /etc/greetd/local.lua by: ./install.sh utm-vm

-- UTM's virtual display defaults to 1280x800; the same mode as the desktop session (utm-vm.lua)
hl.monitor({
    output   = "Virtual-1",
    mode     = "2560x1440@60",
    position = "auto",
    scale    = 1,
})
