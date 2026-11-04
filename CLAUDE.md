# Machines

- This repo configures two machines: `./install.sh utm-vm` for the UTM ARM VM (Arch Linux aarch64 on a Mac, used only for testing and building the config), plain `./install.sh` for the real Linux desktop (probably x86_64).
- The VM part will be removed later, so keep VM workarounds in clearly marked, machine-specific spots (e.g. `machines/utm-vm.lua` → `~/.config/hypr/local.lua`), never in shared config. The shared config must work on the real desktop on its own.
- Choose defaults for real hardware, not the VM. Point out anything that only works on aarch64.
