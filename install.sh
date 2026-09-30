#!/usr/bin/env bash
# Usage: ./install.sh [machine]
#   machine: name of a file in machines/ (without .lua) to install as ~/.config/hypr/local.lua
#            (and machines/<machine>.mise.toml, if any, as ~/.config/mise/conf.d/machine.toml,
#            and machines/<machine>.greeter.lua, if any, as /etc/greetd/local.lua)
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
    [[ $pkg == machines || $pkg == keepassxc || $pkg == browser-policies || $pkg == greeter || $pkg == console ]] && continue
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

# Swap: zram, compressed in RAM, half its size. The sysctls are the usual ones for
# swap this fast: swap before dropping file cache, one page at a time.
sudo install -Dm644 /dev/stdin /etc/systemd/zram-generator.conf <<'INI'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
INI
sudo install -Dm644 /dev/stdin /etc/sysctl.d/99-zram.conf <<'INI'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
INI
sudo sysctl -q --load /etc/sysctl.d/99-zram.conf
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service

# Docker daemon, usable without sudo (group applies from the next login)
sudo systemctl enable --now docker.service
id -nG | grep -qw docker || sudo usermod -aG docker "$USER"

# Firewall: nothing comes in except over Tailscale (the tailnet is trusted, so the
# Mac can reach this machine), everything goes out. Docker publishes container
# ports around ufw, so ufw-docker puts them behind it too: localhost still reaches
# them, other machines only after `sudo ufw-docker allow <container> <port>`.
yay -S --needed --noconfirm ufw-docker
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0
sudo ufw --force enable
sudo systemctl enable ufw.service
sudo ufw-docker install
sudo ufw reload

# Weekly upkeep: paccache keeps the last three versions of each package, fstrim
# tells the SSD which blocks are free, fwupd refreshes the firmware list (updates
# themselves stay manual: fwupdmgr update)
sudo systemctl enable --now paccache.timer fstrim.timer fwupd-refresh.timer

# Login: greetd on tty1. With the root filesystem on LUKS, the disk password at boot
# already proved who is there, so the first session of each boot starts without a
# login, as in Omarchy. After a logout, and on unencrypted machines, the login
# screen (greeter/) asks: a Hyprland of its own running a Quickshell greeter, with
# tuigreet on the console if that fails. The session runs through a zsh login
# shell, so Hyprland gets .zprofile (mise shims, the SSH agent) just as it does
# when started from a tty login.
sudo install -Dm755 /dev/stdin /usr/local/bin/hyprland-session <<'SH'
#!/bin/sh
exec zsh -lc start-hyprland
SH
sudo install -Dm755 greeter/dotfiles-greeter /usr/local/bin/dotfiles-greeter
sudo install -Dm644 greeter/hyprland.lua /etc/greetd/hyprland.lua
sudo install -Dm644 greeter/shell.qml /etc/greetd/quickshell/shell.qml
sudo install -Dm644 hypr/.config/hypr/wallpapers/nord-0-black-moon.jpg /etc/greetd/wallpaper.jpg
# The greeter user's home is /, so it gets one to write caches to
sudo install -d -o greeter -g greeter -m700 /var/lib/dotfiles-greeter
{
    cat <<TOML
[terminal]
vt = 1

[default_session]
command = "env DOTFILES_GREETER_USER=$USER /usr/local/bin/dotfiles-greeter"
user = "greeter"
TOML
    if lsblk -s -no TYPE "$(findmnt -no SOURCE -v /)" | grep -qx crypt; then
        cat <<TOML

[initial_session]
command = "/usr/local/bin/hyprland-session"
user = "$USER"
TOML
    fi
} | sudo install -Dm644 /dev/stdin /etc/greetd/config.toml
# From the next boot; starting it now would stop the tty1 session this may run in
sudo systemctl enable greetd.service

# The console (ttys, and tuigreet if the login screen fails): Nord colours, loaded
# at boot by setvtrgb (console/vtrgb holds Nord's 16 terminal colours, with the
# background as colour 0), and Terminus sized for the screen. The font applies from
# the next boot, and to the disk password prompt once mkinitcpio next runs.
sudo install -Dm644 console/vtrgb /etc/vtrgb
sudo install -Dm644 /dev/stdin /etc/systemd/system/console-nord.service <<'INI'
[Unit]
Description=Nord colours for the Linux console
DefaultDependencies=no
After=systemd-vconsole-setup.service
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/bin/setvtrgb /etc/vtrgb

[Install]
WantedBy=sysinit.target
INI
sudo systemctl daemon-reload
sudo systemctl enable --now console-nord.service
fb_height=$(cut -d, -f2 /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo 0)
if (( fb_height >= 2000 )); then
    console_font=ter-v32b
elif (( fb_height >= 1400 )); then
    console_font=ter-v24b
else
    console_font=ter-v20b
fi
sudo touch /etc/vconsole.conf
sudo sed -i '/^FONT=/d' /etc/vconsole.conf
echo "FONT=$console_font" | sudo tee -a /etc/vconsole.conf >/dev/null

# Keyring: unlocked with the login password (tty or tuigreet), and re-encrypted
# when passwd changes it. An auto-login has no password, so the keyring asks for
# it once, the first time an app needs a secret. PAM keeps one stack per type, so
# appending lands each line last in its stack; optional means a keyring failure
# never blocks a login.
pam_add() {
    grep -qxF "$2" "$1" || echo "$2" | sudo tee -a "$1" >/dev/null
}
for pam in login greetd; do
    pam_add /etc/pam.d/$pam "auth       optional     pam_gnome_keyring.so"
    pam_add /etc/pam.d/$pam "session    optional     pam_gnome_keyring.so auto_start"
done
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

# Papirus icons everywhere (GTK apps, the fuzzel launcher), folders in Nord blue-grey
# (Papirus-Light shares them)
yay -S --needed --noconfirm papirus-folders
sudo papirus-folders -C nordic --theme Papirus-Dark
# Light or dark: darkman (started by Hyprland) runs scripts/theme at sunrise and
# sunset. Dark until it first does; this also creates fuzzel's theme.ini, which
# fuzzel won't start without.
[[ -e $HOME/.config/fuzzel/theme.ini ]] || "$HOME/.config/hypr/scripts/theme" dark

if [[ -n ${1:-} ]]; then
    src=machines/$1.lua
    dst=$HOME/.config/hypr/local.lua
    [[ -f $src ]] || { echo "No such machine: $src" >&2; exit 1; }
    if [[ -e $dst ]] && ! cmp -s "$src" "$dst"; then
        echo "$dst exists and differs from $src; leaving it alone" >&2
    else
        cp "$src" "$dst"
    fi
    # The login screen's monitors, if the machine needs them set
    if [[ -f machines/$1.greeter.lua ]]; then
        sudo install -Dm644 "machines/$1.greeter.lua" /etc/greetd/local.lua
    fi
fi

# NetworkManager takes over from systemd-networkd and iwd (the bar's network dropdown
# needs it). Last, since the switch drops the connection for a few seconds.
if ! systemctl is-enabled --quiet NetworkManager.service; then
    # Wi-Fi networks iwd saved (archinstall's Wi-Fi option) become NetworkManager
    # connections first, so a machine on Wi-Fi comes back online. iwd names each file
    # after the SSID, or =<hex of the SSID> when it has other characters.
    while IFS= read -r -d '' -u 3 file; do
        name=${file##*/}
        name=${name%.*}
        ssid=$name
        [[ $name == =* ]] && ssid=$(printf '%b' "$(sed 's/../\\x&/g' <<<"${name#=}")")
        security=()
        if [[ $file == *.psk ]]; then
            psk=$(sudo sed -n 's/^Passphrase=//p' "$file")
            [[ -n $psk ]] || psk=$(sudo sed -n 's/^PreSharedKey=//p' "$file")
            [[ -n $psk ]] || continue
            security=(wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk")
        fi
        nm_file="/etc/NetworkManager/system-connections/iwd-$name.nmconnection"
        sudo test -e "$nm_file" && continue
        nmcli --offline connection add type wifi con-name "$ssid" ssid "$ssid" "${security[@]}" |
            sudo install -Dm600 /dev/stdin "$nm_file"
    done 3< <(sudo find /var/lib/iwd -maxdepth 1 \( -name '*.psk' -o -name '*.open' \) -print0 2>/dev/null)

    # networkd comes with sockets that restart it, so they all stop in one go
    # (stopping only the service fails)
    sudo systemctl disable systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service
    sudo systemctl stop 'systemd-networkd*'
    # iwd and NetworkManager's wpa_supplicant can't share the Wi-Fi card
    if [[ -e /usr/lib/systemd/system/iwd.service ]]; then
        sudo systemctl disable --now iwd.service
    fi
    sudo systemctl enable --now NetworkManager.service
    if ! nm-online -q -t 30; then
        echo "No network after the switch to NetworkManager; connect with nmtui" \
            "(enterprise and WPA3-only Wi-Fi aren't carried over from iwd)" >&2
    fi
fi
