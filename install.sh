#!/usr/bin/env bash
# Usage: ./install.sh [machine]
#   machine: name of a file in machines/ (without .lua) to install as ~/.config/hypr/local.lua
#            (and machines/<machine>.mise.toml, if any, as ~/.config/mise/conf.d/machine.toml)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

sudo pacman -S --needed - < <(grep -vE '^\s*(#|$)' packages.txt)

# Hardware-specific packages, only on machines that have the hardware.
# AMD CPU: microcode updates, loaded early by mkinitcpio's microcode hook.
grep -q '^vendor_id.*AuthenticAMD' /proc/cpuinfo && sudo pacman -S --needed amd-ucode
# AMD GPU, integrated or a card (PCI vendor 0x1002): Mesa's OpenGL and video
# decoding, and its Vulkan driver
grep -qx 0x1002 /sys/class/drm/card*/device/vendor 2>/dev/null && sudo pacman -S --needed mesa vulkan-radeon

for pkg in */; do
    pkg=${pkg%/}
    [[ $pkg == machines || $pkg == keepassxc || $pkg == browser-policies ]] && continue
    stow --no-folding --restow -t "$HOME" "$pkg"
done

# zsh as the login shell (zsh/.zprofile starts Hyprland); chsh asks for the password
[[ $(getent passwd "$USER" | cut -d: -f7) == /usr/bin/zsh ]] || chsh -s /usr/bin/zsh

# tmux plugins: tpm itself, then the plugins tmux.conf lists
if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

# mise: dev tools from ~/.config/mise/config.toml (Node, pnpm, Go, Java, …). Arch Linux
# ARM has no mise package, so there it comes from mise's own installer.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null; then
    if pacman -Si mise &>/dev/null; then
        sudo pacman -S --needed mise
    else
        curl -fsSL https://mise.run | sh
    fi
fi
if [[ -n ${1:-} && -f machines/$1.mise.toml ]]; then
    mkdir -p "$HOME/.config/mise/conf.d"
    cp "machines/$1.mise.toml" "$HOME/.config/mise/conf.d/machine.toml"
fi
mise install

# yay, for what only the AUR has, as in Omarchy; built by hand the first time
if ! command -v yay >/dev/null; then
    yay_build=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$yay_build"
    (cd "$yay_build" && makepkg -si --noconfirm)
    rm -rf "$yay_build"
fi
# Brave Origin: Brave without Rewards, Wallet, VPN and the AI assistant
yay -S --needed --noconfirm brave-origin-bin
# cliamp: Winamp-style terminal music player (SUPER + SHIFT + M), as in Omarchy
yay -S --needed --noconfirm cliamp-bin

# Claude Code: Anthropic's native installer, which keeps it updated itself
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash

# Audio: WirePlumber and the PulseAudio socket, in the user session
systemctl --user enable --now wireplumber.service pipewire-pulse.socket

# Bluetooth daemon; the bar hides its icon on machines without an adapter
sudo systemctl enable --now bluetooth.service

# Tailscale daemon, with the user as its operator so the bar can connect, disconnect
# and pick exit nodes without sudo (the setting waits until tailscaled is listening)
sudo systemctl enable --now tailscaled.service
for _ in {1..10}; do
    sudo tailscale set --operator="$USER" 2>/dev/null && break
    sleep 1
done

# Docker daemon, usable without sudo (group applies from the next login)
sudo systemctl enable --now docker.service
id -nG | grep -qw docker || sudo usermod -aG docker "$USER"

# Keyring: unlocked with the tty login password, and re-encrypted when passwd
# changes it. PAM keeps one stack per type, so appending lands each line last in
# its stack; optional means a keyring failure never blocks a login.
pam_add() {
    grep -qxF "$2" "$1" || echo "$2" | sudo tee -a "$1" >/dev/null
}
pam_add /etc/pam.d/login  "auth       optional     pam_gnome_keyring.so"
pam_add /etc/pam.d/login  "session    optional     pam_gnome_keyring.so auto_start"
pam_add /etc/pam.d/passwd "password   optional     pam_gnome_keyring.so"

# SSH agent that asks for key passphrases graphically and can remember them in
# the keyring. .zprofile points SSH_AUTH_SOCK at it.
systemctl --user enable --now gcr-ssh-agent.socket

# KeePassXC rewrites its settings and native messaging files in place, so they
# are seeded rather than stowed. The ini turns on browser integration and the
# SSH agent, and leaves Secret Service to gnome-keyring.
kpxc_ini=$HOME/.config/keepassxc/keepassxc.ini
if [[ ! -e $kpxc_ini ]]; then
    mkdir -p "${kpxc_ini%/*}"
    cp keepassxc/keepassxc.ini "$kpxc_ini"
fi
# Chromium and Brave Origin connect to KeePassXC only while this manifest
# exists; KeePassXC refreshes Chromium's on every start.
for profile in chromium BraveSoftware/Brave-Origin; do
    kpxc_host=$HOME/.config/$profile/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json
    [[ -e $kpxc_host ]] && continue
    mkdir -p "${kpxc_host%/*}"
    cat >"$kpxc_host" <<'JSON'
{
    "allowed_origins": [
        "chrome-extension://pdffhmdngciaglkoonimfcmckehcpafo/",
        "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"
    ],
    "description": "KeePassXC integration with native messaging support",
    "name": "org.keepassxc.keepassxc_browser",
    "path": "/usr/bin/keepassxc-proxy",
    "type": "stdio"
}
JSON
done
# KeePassXC-Browser, installed into Chromium from the Web Store on next start
sudo install -Dm644 /dev/stdin /usr/share/chromium/extensions/oboonakemofpalcgghocfoadofidjkkk.json \
    <<<'{ "external_update_url": "https://clients2.google.com/service/update2/crx" }'
# Browser policies (browser-policies/), merged by the browser from its managed dir.
# common.json, for both: Google's AI features off (Gemini, AI Mode, Lens, Help me
# write, the on-device model), no telemetry or Privacy Sandbox ad tracking, no
# promotions, and no password manager of their own since KeePassXC is it.
# chromium.json: it stops asking to be the default browser.
# brave.json: the same, and KeePassXC-Browser and Vimium from the Web Store
# (removable only here).
for browser in chromium:/etc/chromium/policies/managed brave:/etc/brave/policies/managed; do
    dir=${browser#*:}
    sudo install -Dm644 browser-policies/common.json "$dir/dotfiles-common.json"
    sudo install -Dm644 "browser-policies/${browser%%:*}.json" "$dir/dotfiles.json"
done

# Folders open in Nautilus (xdg-open, Chromium's "Show in folder")
xdg-mime default org.gnome.Nautilus.desktop inode/directory
# PDFs open in Papers (GNOME's GTK 4 viewer, so it takes the Nord gtk.css)
xdg-mime default org.gnome.Papers.desktop application/pdf
# Images open in imv
xdg-mime default imv.desktop image/png image/jpeg image/gif image/webp image/bmp image/tiff

# Dark GTK apps, as in Omarchy: libadwaita (Nautilus) reads color-scheme through
# xdg-desktop-portal-gtk, older GTK 3 apps the theme name
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark

if [[ -n ${1:-} ]]; then
    src=machines/$1.lua
    dst=$HOME/.config/hypr/local.lua
    [[ -f $src ]] || { echo "No such machine: $src" >&2; exit 1; }
    if [[ -e $dst ]] && ! cmp -s "$src" "$dst"; then
        echo "$dst exists and differs from $src; leaving it alone" >&2
    else
        cp "$src" "$dst"
    fi
fi

# NetworkManager takes over from systemd-networkd (the bar's network dropdown needs it).
# Last, since the switch drops the connection for a few seconds. networkd comes with
# sockets that restart it, so they all stop in one go (stopping only the service fails).
if ! systemctl is-enabled --quiet NetworkManager.service; then
    sudo systemctl disable systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service
    sudo systemctl stop 'systemd-networkd*'
    sudo systemctl enable --now NetworkManager.service
fi
