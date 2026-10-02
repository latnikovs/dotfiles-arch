#!/usr/bin/env bash
# Usage: ./install.sh [machine]
#   machine: name of a file in machines/ (without .lua) to install as ~/.config/hypr/local.lua
#            (and machines/<machine>.mise.toml, if any, as ~/.config/mise/conf.d/machine.toml,
#            machines/<machine>.greeter.lua, if any, as /etc/greetd/local.lua, and
#            machines/<machine>.wireplumber.conf, if any, as ~/.config/wireplumber/wireplumber.conf.d/50-machine.conf,
#            machines/<machine>.hwdb, if any, as /etc/udev/hwdb.d/90-machine.hwdb)
#
# On a fresh Arch install, straight from GitHub (add `-s -- <machine>` after bash for a machine):
#   curl -fsSL https://raw.githubusercontent.com/latnikovs/dotfiles-arch/main/install.sh | bash
set -euo pipefail

# Piped into bash there is no script file: install git, clone the repo to ~/dotfiles
# (or update it) and run its copy of this script. That copy reads from the terminal,
# not from the pipe, so the sudo password comes from the keyboard.
if [[ ! -f ${BASH_SOURCE[0]:-} ]]; then
    sudo pacman -S --needed --noconfirm git
    if [[ -d $HOME/dotfiles/.git ]]; then
        git -C "$HOME/dotfiles" pull --ff-only
    else
        git clone https://github.com/latnikovs/dotfiles-arch.git "$HOME/dotfiles"
    fi
    exec "$HOME/dotfiles/install.sh" "$@" </dev/tty
fi

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

machine=${1:-}
if [[ -n $machine && ! -f machines/$machine.lua ]]; then
    echo "No such machine: machines/$machine.lua" >&2
    exit 1
fi

# ── Output ───────────────────────────────────────────────────────────────────
# The terminal gets a short list of steps. Everything else, each command (traced)
# and all it prints, goes to a log in ~/.local/state/dotfiles; install.log there is
# the latest. A failed step shows the end of the log.
log_dir=$HOME/.local/state/dotfiles
log=$log_dir/install-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$log_dir"
(umask 077 && : >"$log")
ln -sfn "${log##*/}" "$log_dir/install.log"
# The ten newest are kept (the names sort by date)
logs=("$log_dir"/install-*.log)
if (( ${#logs[@]} > 10 )); then
    rm -f "${logs[@]:0:${#logs[@]}-10}"
fi

# On a terminal, a spinner and colours; otherwise (piped, redirected) one plain line
# per finished step. Icons: Nerd Font symbols in terminals that bundle them, plain
# Unicode in others, ASCII on the Linux console, whose fonts have neither.
# DOTFILES_ICONS=nerd|unicode|ascii overrides the guess, NO_COLOR turns colours off.
ui=plain clear_line='' c_reset='' c_bold='' c_dim='' c_red='' c_green='' c_yellow='' c_blue='' c_cyan=''
if [[ -t 1 ]]; then
    ui=fancy
    clear_line=$'\r\e[K'
    if [[ -z ${NO_COLOR:-} ]]; then
        c_reset=$'\e[0m' c_bold=$'\e[1m' c_dim=$'\e[90m' c_red=$'\e[31m' c_green=$'\e[32m'
        c_yellow=$'\e[33m' c_blue=$'\e[34m' c_cyan=$'\e[36m'
    fi
fi
icons=${DOTFILES_ICONS:-}
if [[ -z $icons ]]; then
    case ${TERM:-} in
        linux) icons=ascii ;;
        xterm-kitty | xterm-ghostty) icons=nerd ;;
        *) icons=unicode ;;
    esac
fi
declare -A glyph
case $icons in
    nerd)
        # check, xmark, warning, info-circle, file-text, lock, flag-checkered, archlinux,
        # angle-right; then the sections: package, link, apps, cogs, desktop, monitor, wifi
        glyph=([ok]=$'\uf00c' [fail]=$'\uf00d' [warn]=$'\uf071' [note]=$'\uf05a' [log]=$'\uf15c'
            [lock]=$'\uf023' [done]=$'\uf11e' [title]=$'\uf303' [section]=$'\uf105' [sep]=·
            [packages]=$'\U000f03d7' [dotfiles]=$'\uf0c1' [apps]=$'\U000f003b' [services]=$'\uf085'
            [desktop]=$'\uf108' [machine]=$'\U000f0379' [network]=$'\U000f05a9')
        spinner=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) ;;
    unicode)
        glyph=([ok]=✓ [fail]=✗ [warn]=! [note]=› [log]=› [lock]=› [title]=◆ [section]=▸ [sep]=·)
        spinner=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) ;;
    *)
        glyph=([ok]=+ [fail]=x [warn]=! [note]=- [log]=- [lock]=- [title]='*' [section]='>' [sep]=-)
        spinner=('|' / - "\\") ;;
esac

now() { printf -v "$1" '%(%s)T' -1; }
# duration <var> <seconds>: 42s, 3m07s
duration() {
    if (( $2 >= 60 )); then
        printf -v "$1" '%dm%02ds' $(( $2 / 60 )) $(( $2 % 60 ))
    else
        printf -v "$1" '%ds' "$2"
    fi
}

# While a step works: its title, how long it has taken and the log's latest line
spin() {
    trap - EXIT
    local title=$1 start=$2 cols i=0 t took line room
    cols=$(stty size </dev/tty 2>/dev/null) && cols=${cols#* } || cols=0
    (( cols > 0 )) || cols=80
    while kill -0 $$ 2>/dev/null; do
        now t
        duration took $(( t - start ))
        line=$(tail -n 1 "$log" 2>/dev/null) || line=''
        line=${line##*$'\r'}
        line=${line//[^[:print:]]/}
        # A traced command: "+ <line number>: command"
        [[ $line =~ ^\++\ [0-9]+:\ (.*) ]] && line=${BASH_REMATCH[1]}
        room=$(( cols - 12 - ${#title} - ${#took} ))
        (( room > 8 )) && line="  ${line:0:room}" || line=''
        printf '%s   %s %s %s%s%s' "$clear_line" "$c_cyan${spinner[i++ % ${#spinner[@]}]}$c_reset" \
            "$title" "$c_dim$took" "$line" "$c_reset" >&3
        sleep 0.15
    done
}
spin_pid=''
spin_stop() {
    [[ -n $spin_pid ]] || return 0
    kill "$spin_pid" 2>/dev/null || true
    wait "$spin_pid" 2>/dev/null || true
    spin_pid=''
}

step_title='' step_start=0 step_notes=() warnings=()
# mark <icon>: the running step's final line, with the time it took and its notes
mark() {
    local t took=''
    now t
    (( t - step_start < 1 )) || duration took $(( t - step_start ))
    printf '%s   %s %-34s %s\n' "$clear_line" "$1" "$step_title" "$c_dim$took$c_reset" >&3
    (( ${#step_notes[@]} == 0 )) || printf '%s\n' "${step_notes[@]}" >&3
    step_notes=()
}
step_end() {
    [[ -n $step_title ]] || return 0
    spin_stop
    mark "$c_green${glyph[ok]}$c_reset"
    step_title=''
}
# step <title>: ends the running step, as done, and starts this one
step() {
    { set +x; } 2>/dev/null
    step_end
    step_title=$1
    now step_start
    printf '\n==> %s\n' "$1"
    if [[ $ui == fancy ]]; then
        spin "$1" "$step_start" &
        spin_pid=$!
    fi
    set -x
}
# section <icon> <title>
section() {
    { set +x; } 2>/dev/null
    step_end
    printf '\n %s %s\n' "$c_blue${glyph[$1]:-${glyph[section]}}$c_reset" "$c_bold$2$c_reset" >&3
    printf '\n### %s\n' "$2"
    set -x
}
# Shown under the running step once it ends; warnings again in the summary
warn() {
    { set +x; } 2>/dev/null
    warnings+=("$1")
    printf 'warning: %s\n' "$1"
    step_notes+=("     $c_yellow${glyph[warn]} $1$c_reset")
    set -x
}
note() {
    { set +x; } 2>/dev/null
    printf 'note: %s\n' "$1"
    step_notes+=("     $c_blue${glyph[note]}$c_reset $1")
    set -x
}

run_start=0
now run_start
log_shown=${log/#"$HOME"/\~}
finish() {
    { set +x; } 2>/dev/null
    step_end
    local t took w count=''
    now t
    duration took $(( t - run_start ))
    case ${#warnings[@]} in
        0) ;;
        1) count=", ${c_yellow}1 warning$c_reset" ;;
        *) count=", $c_yellow${#warnings[@]} warnings$c_reset" ;;
    esac
    printf '\n %s %s in %s%s\n' "$c_green${glyph[done]:-${glyph[ok]}}$c_reset" "${c_bold}Done$c_reset" "$took" "$count" >&3
    for w in "${warnings[@]}"; do
        printf '   %s\n' "$c_yellow${glyph[warn]} $w$c_reset" >&3
    done
    printf '   %s\n' "$c_dim${glyph[log]} Log: $log_shown$c_reset" \
        "$c_dim${glyph[note]} After the first run, reboot for the login screen$c_reset" >&3
}
# On a failure (set -e) or Ctrl+C: the step that failed and the end of the log
on_exit() {
    { set +x; } 2>/dev/null
    local status=$1
    spin_stop
    [[ -z ${sudo_keepalive:-} ]] || kill "$sudo_keepalive" 2>/dev/null || true
    if (( status != 0 )); then
        [[ -z $step_title ]] || mark "$c_red${glyph[fail]}$c_reset"
        if (( status == 130 )); then
            printf '\n %s\n' "$c_red${c_bold}Interrupted$c_reset" >&3
        else
            printf '\n %s %s\n' "$c_red${c_bold}Failed$c_reset" "${c_dim}(exit $status); the step's log ends with:$c_reset" >&3
            # From the failed step's own part of the log, the last 15 lines
            awk '/^==> /{n=0; next} !/: on_exit [0-9]+$/{line[++n]=$0}
                END{for (i = n > 15 ? n - 14 : 1; i <= n; i++) print line[i]}' "$log" |
                sed "s/^/     $c_dim/; s/\$/$c_reset/" >&3
        fi
        printf '\n   %s\n   %s\n' "${glyph[log]} Full log: $log_shown" \
            "${glyph[note]} Fix the problem and run ./install.sh${machine:+ $machine} again; it picks up where it can" >&3
    fi
    [[ $ui != fancy ]] || printf '\e[?25h' >&3
}

printf '\n %s %s\n   %s\n' "$c_blue${glyph[title]}$c_reset" "${c_bold}Dotfiles$c_reset${machine:+ $c_dim${glyph[sep]}$c_reset $machine}" \
    "$c_dim${glyph[log]} Log: $log_shown$c_reset"
# The password, once: kept fresh in the background so no later sudo asks for it
# behind the spinner
sudo -v -p "   ${glyph[lock]} sudo password for %u: "

exec 3>&1
exec >>"$log" 2>&1 </dev/null
trap 'on_exit $?' EXIT
[[ $ui != fancy ]] || printf '\e[?25l' >&3
while kill -0 $$ 2>/dev/null; do sudo -n -v; sleep 60; done &
sudo_keepalive=$!
printf '%s: ./install.sh %s on %s (%s), dotfiles at %s\n' "$(date '+%F %T')" "$machine" "$(uname -n)" \
    "$(uname -m)" "$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
PS4='+ ${LINENO}: '
set -x

# ── Install ──────────────────────────────────────────────────────────────────
section packages Packages
step 'System packages'
sudo pacman -S --needed --noconfirm - < <(grep -vE '^\s*(#|$)' packages.txt)

# Hardware-specific packages, only on machines that have the hardware.
# AMD CPU: microcode updates, loaded early by mkinitcpio's microcode hook.
if grep -q '^vendor_id.*AuthenticAMD' /proc/cpuinfo; then
    step 'AMD microcode'
    sudo pacman -S --needed --noconfirm amd-ucode
fi
# AMD GPU, integrated or a card (PCI vendor 0x1002): Mesa's OpenGL and video
# decoding, and its Vulkan driver
if grep -qx 0x1002 /sys/class/drm/card*/device/vendor 2>/dev/null; then
    step 'AMD graphics drivers'
    sudo pacman -S --needed --noconfirm mesa vulkan-radeon
fi

section dotfiles Dotfiles
step 'Linking configs (stow)'
for pkg in */; do
    pkg=${pkg%/}
    [[ $pkg == machines || $pkg == keepassxc || $pkg == browser-policies || $pkg == greeter || $pkg == console || $pkg == syncthing ]] && continue
    stow --no-folding --restow -t "$HOME" "$pkg"
done

# zsh as the login shell (zsh/.zprofile starts Hyprland); through sudo, so chsh
# doesn't ask for the password
step 'Login shell: zsh'
if [[ $(getent passwd "$USER" | cut -d: -f7) != /usr/bin/zsh ]]; then
    sudo chsh -s /usr/bin/zsh "$USER"
fi

step 'tmux plugins'
# tmux plugins: tpm itself, then the plugins tmux.conf lists
if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

step 'mise and dev tools'
# mise: dev tools from ~/.config/mise/config.toml (Node, pnpm, Go, Java, …). Arch Linux
# ARM has no mise package, so there it comes from mise's own installer.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null; then
    if pacman -Si mise &>/dev/null; then
        sudo pacman -S --needed --noconfirm mise
    else
        curl -fsSL https://mise.run | sh
    fi
fi
if [[ -n $machine && -f machines/$machine.mise.toml ]]; then
    mkdir -p "$HOME/.config/mise/conf.d"
    cp "machines/$machine.mise.toml" "$HOME/.config/mise/conf.d/machine.toml"
fi
# Audio rules the machine needs (read when WirePlumber starts)
if [[ -n $machine && -f machines/$machine.wireplumber.conf ]]; then
    mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
    cp "machines/$machine.wireplumber.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/50-machine.conf"
fi
mise install

section apps Apps
# yay, for what only the AUR has, as in Omarchy; built by hand the first time
if ! command -v yay >/dev/null; then
    step 'yay (AUR helper)'
    yay_build=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$yay_build"
    (cd "$yay_build" && makepkg -si --noconfirm)
    rm -rf "$yay_build"
fi
step 'Brave Origin, cliamp, herdr, gtypist (AUR)'
# Brave Origin: Brave without Rewards, Wallet, VPN and the AI assistant
yay -S --needed --noconfirm brave-origin-bin
# cliamp: Winamp-style terminal music player (SUPER + SHIFT + M), as in Omarchy
yay -S --needed --noconfirm cliamp-bin
# herdr: terminal workspace manager for supervising several coding agents at once
yay -S --needed --noconfirm herdr-bin
# gtypist: GNU Typist, touch-typing lessons in the terminal. Its tarball is signed and
# the keyservers yay asks return the key without user IDs, so import the copy the AUR
# package ships (the PKGBUILD pins the fingerprint)
gtypist_key=02AEC665007301C280C5C43A0FB807D2E7C7C96C
if ! gpg --list-keys "$gtypist_key" &>/dev/null; then
    curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/keys/pgp/$gtypist_key.asc?h=gtypist" | gpg --import
fi
yay -S --needed --noconfirm gtypist

step 'Claude Code'
# Claude Code: Anthropic's native installer, which keeps it updated itself
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
# Its status line (claude/.claude/statusline.sh). settings.json also holds what
# each machine sets for itself (plugins, permissions), so only this key is set.
claude_settings=$HOME/.claude/settings.json
[[ -s $claude_settings ]] || echo '{}' >"$claude_settings"
jq '.statusLine = {"type": "command", "command": "~/.claude/statusline.sh"}' "$claude_settings" >"$claude_settings.new"
mv "$claude_settings.new" "$claude_settings"

section services Services
step 'Audio (PipeWire)'
# Audio: WirePlumber and the PulseAudio socket, in the user session
systemctl --user enable --now wireplumber.service pipewire-pulse.socket

step 'Bluetooth'
# Bluetooth daemon; the bar hides its icon on machines without an adapter
sudo systemctl enable --now bluetooth.service

step 'Tailscale'
# Tailscale daemon, with the user as its operator so the bar can connect, disconnect
# and pick exit nodes without sudo (the setting waits until tailscaled is listening)
sudo systemctl enable --now tailscaled.service
for _ in {1..10}; do
    sudo tailscale set --operator="$USER" 2>/dev/null && break
    sleep 1
done

step 'Syncthing'
# Syncthing: ~/notes and ~/Documents, with paired devices over Tailscale only
# (syncthing/setup; pairing is by hand, see the README)
systemctl --user enable --now syncthing.service
syncthing_id=$(syncthing/setup | sed -n 's/^Syncthing device ID: //p')
note "Device ID: $syncthing_id"

step 'Swap on zram'
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

step 'Docker, rootless'
# Docker, rootless: the daemon is a user service, so containers can do no more than
# you can. (The docker group would hand out root without a password.) Published
# ports are ordinary user processes, which the firewall below covers like any other.
# .zprofile points DOCKER_HOST (and Testcontainers) at the user daemon's socket.
yay -S --needed --noconfirm docker-rootless-extras
# User namespace ids for the containers (useradd normally adds these)
if ! grep -q "^$USER:" /etc/subuid; then
    sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
fi
# Lets containers take CPU, memory and I/O limits (docker run --memory …)
sudo install -Dm644 /dev/stdin /etc/systemd/system/user@.service.d/delegate.conf <<'INI'
[Service]
Delegate=cpu cpuset io memory pids
INI
sudo systemctl daemon-reload
# The system-wide daemon and the docker group, from before rootless
sudo systemctl disable --now docker.service docker.socket
if getent group docker | cut -d: -f4 | tr , '\n' | grep -qx "$USER"; then
    sudo gpasswd -d "$USER" docker
fi
systemctl --user enable --now docker.socket

step 'Firewall (ufw)'
# Firewall: nothing comes in except over Tailscale (the tailnet is trusted, so the
# Mac can reach this machine), everything goes out
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0
sudo ufw --force enable
sudo systemctl enable ufw.service
sudo ufw reload

step 'SSH server'
# SSH server, reachable only over Tailscale (the firewall above): keys only, no
# root. The Mac's key goes in ~/.ssh/authorized_keys by hand.
sudo install -Dm644 /dev/stdin /etc/ssh/sshd_config.d/10-hardening.conf <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
CONF
sudo sshd -t
sudo systemctl enable --now sshd.service

step 'Maintenance timers'
# Weekly upkeep: paccache keeps the last three versions of each package, fstrim
# tells the SSD which blocks are free, fwupd refreshes the firmware list (updates
# themselves stay manual: fwupdmgr update)
sudo systemctl enable --now paccache.timer fstrim.timer fwupd-refresh.timer

section desktop Desktop
step 'Login screen (greetd)'
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

step 'Console colours and font'
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

step 'Keyring and SSH agent'
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

step 'KeePassXC and browser policies'
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

step 'Default apps'
# Folders open in Nautilus (xdg-open, Chromium's "Show in folder")
xdg-mime default org.gnome.Nautilus.desktop inode/directory
# PDFs open in Papers (GNOME's GTK 4 viewer, so it takes the Nord gtk.css)
xdg-mime default org.gnome.Papers.desktop application/pdf
# Images open in imv
xdg-mime default imv.desktop image/png image/jpeg image/gif image/webp image/bmp image/tiff

step 'Icon themes'
# Papirus icons for GTK apps, folders in Nord blue-grey (Papirus-Light shares them)
yay -S --needed --noconfirm papirus-folders
sudo papirus-folders -C nordic --theme Papirus-Dark
# The fuzzel launcher uses Nordzy's Nord-coloured app icons instead, through the
# Nordzy-Launcher-* themes in icons/, which fall back to Papirus. Only the two variants
# we use, from the release; the AUR package builds all 18 (~1 GB, many minutes).
pacman -Q nordzy-icon-theme &>/dev/null && sudo pacman -Rns --noconfirm nordzy-icon-theme
nordzy_version=1.8.7
icon_dir=$HOME/.local/share/icons
mkdir -p "$icon_dir"
while read -r theme sha256; do
    [[ $(cat "$icon_dir/$theme/.version" 2>/dev/null) == "$nordzy_version" ]] && continue
    tarball=$(mktemp)
    curl -fsSL "https://github.com/alvatip/Nordzy-icon/releases/download/$nordzy_version/$theme.tar.gz" -o "$tarball"
    sha256sum --quiet -c <<<"$sha256  $tarball"
    rm -rf "${icon_dir:?}/$theme"
    tar -xzf "$tarball" -C "$icon_dir"
    echo "$nordzy_version" >"$icon_dir/$theme/.version"
    rm -f "$tarball"
done <<'NORDZY'
Nordzy 38c346bc4de165b79d5b678284b63cc0fa058dccea29ec1b6fabea7117d7b8ad
Nordzy-dark ad752b5ce70577408431734fc8004f928a00027a8fce6dd131ae2d0c3dc82069
NORDZY
# Icons for the apps Nordzy lacks (stow won't link outside the repo, so they're made here)
for variant in Light:Nordzy Dark:Nordzy-dark; do
    dir=$icon_dir/Nordzy-Launcher-${variant%%:*}/apps/scalable
    src=$icon_dir/${variant#*:}/apps/scalable
    mkdir -p "$dir"
    while read -r name icon; do
        ln -sfn "$src/$icon.svg" "$dir/$name.svg"
    done <<'ICONS'
brave-origin brave
cliamp elisa
org.gnome.Papers accessories-document-viewer
multimedia-photo-viewer accessories-image-viewer
preferences-desktop-keyboard-shortcuts org.xfce.settings.keyboard
ICONS
done
step 'Light/dark theme'
# Light or dark: darkman (started by Hyprland) runs scripts/theme at sunrise and
# sunset. Dark until it first does; this also creates fuzzel's theme.ini, which
# fuzzel won't start without.
[[ -e $HOME/.config/fuzzel/theme.ini ]] || "$HOME/.config/hypr/scripts/theme" dark

if [[ -n $machine ]]; then
    section machine "Machine: $machine"
    step 'Hyprland overrides'
    src=machines/$machine.lua
    dst=$HOME/.config/hypr/local.lua
    if [[ -e $dst ]] && ! cmp -s "$src" "$dst"; then
        warn "${dst/#"$HOME"/\~} differs from $src; left alone"
    else
        cp "$src" "$dst"
    fi
    # The login screen's monitors, if the machine needs them set
    if [[ -f machines/$machine.greeter.lua ]]; then
        step 'Login screen monitors'
        sudo install -Dm644 "machines/$machine.greeter.lua" /etc/greetd/local.lua
    fi
    # Key remaps the machine's keyboard needs, applied to keyboards already plugged in
    if [[ -f machines/$machine.hwdb ]] && ! cmp -s "machines/$machine.hwdb" /etc/udev/hwdb.d/90-machine.hwdb; then
        step 'Keyboard remaps'
        sudo install -Dm644 "machines/$machine.hwdb" /etc/udev/hwdb.d/90-machine.hwdb
        sudo systemd-hwdb update
        sudo udevadm trigger --subsystem-match=input --action=change
    fi
fi

# NetworkManager takes over from systemd-networkd and iwd (the bar's network dropdown
# needs it). Last, since the switch drops the connection for a few seconds.
if ! systemctl is-enabled --quiet NetworkManager.service; then
    section network Network
    step 'Wi-Fi networks from iwd'
    # Not traced: the log would get the Wi-Fi passwords
    { set +x; } 2>/dev/null
    # Wi-Fi networks iwd saved (archinstall's Wi-Fi option) become NetworkManager
    # connections first, so a machine on Wi-Fi comes back online. iwd names each file
    # after the SSID, or =<hex of the SSID> when it has other characters.
    while IFS= read -r -d '' -u 4 file; do
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
    done 4< <(sudo find /var/lib/iwd -maxdepth 1 \( -name '*.psk' -o -name '*.open' \) -print0 2>/dev/null)
    set -x

    step 'Switching to NetworkManager'
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
        warn "No network after the switch to NetworkManager; connect with nmtui (enterprise and WPA3-only Wi-Fi aren't carried over from iwd)"
    fi
fi

finish
