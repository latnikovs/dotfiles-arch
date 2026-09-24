#!/usr/bin/env bash
# Usage: ./install.sh [machine]
#   machine: name of a file in machines/ (without .lua) to install as ~/.config/hypr/local.lua
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

sudo pacman -S --needed - < <(grep -vE '^\s*(#|$)' packages.txt)

for pkg in */; do
    pkg=${pkg%/}
    [[ $pkg == machines || $pkg == keepassxc ]] && continue
    stow --no-folding --restow -t "$HOME" "$pkg"
done

# tmux plugins: tpm itself, then the plugins tmux.conf lists
if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

# mise: dev tools from ~/.config/mise/config.toml (Node, Go, Java, …). Arch Linux
# ARM has no mise package, so there it comes from mise's own installer.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null; then
    if pacman -Si mise &>/dev/null; then
        sudo pacman -S --needed mise
    else
        curl -fsSL https://mise.run | sh
    fi
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

# Claude Code: Anthropic's native installer, which keeps it updated itself
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash

# Audio: WirePlumber and the PulseAudio socket, in the user session
systemctl --user enable --now wireplumber.service pipewire-pulse.socket

# Bluetooth daemon; the bar hides its icon on machines without an adapter
sudo systemctl enable --now bluetooth.service

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
# the keyring. .bash_profile points SSH_AUTH_SOCK at it.
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
# KeePassXC is the password manager, so Chromium stops offering to save its own
sudo install -Dm644 /dev/stdin /etc/chromium/policies/managed/dotfiles.json \
    <<<'{ "PasswordManagerEnabled": false }'
# Brave Origin: the same, and KeePassXC-Browser and Vimium installed from the
# Web Store (removable only by changing this policy)
sudo install -Dm644 /dev/stdin /etc/brave/policies/managed/dotfiles.json <<'JSON'
{
    "PasswordManagerEnabled": false,
    "ExtensionSettings": {
        "oboonakemofpalcgghocfoadofidjkkk": {
            "installation_mode": "normal_installed",
            "update_url": "https://clients2.google.com/service/update2/crx"
        },
        "dbepggeogbaibhgnhhndojpepiihcmeb": {
            "installation_mode": "normal_installed",
            "update_url": "https://clients2.google.com/service/update2/crx"
        }
    }
}
JSON

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
