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

# yazi flavors pinned in package.toml
ya pkg install

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
# Chromium connects to KeePassXC only while this manifest exists; KeePassXC
# refreshes it on every start.
kpxc_host=$HOME/.config/chromium/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json
if [[ ! -e $kpxc_host ]]; then
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
fi
# KeePassXC-Browser, installed into Chromium from the Web Store on next start
sudo install -Dm644 /dev/stdin /usr/share/chromium/extensions/oboonakemofpalcgghocfoadofidjkkk.json \
    <<<'{ "external_update_url": "https://clients2.google.com/service/update2/crx" }'

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
