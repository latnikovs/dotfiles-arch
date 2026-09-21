#!/usr/bin/env bash
# Usage: ./install.sh [machine]
#   machine: name of a file in machines/ (without .lua) to install as ~/.config/hypr/local.lua
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

sudo pacman -S --needed - < <(grep -vE '^\s*(#|$)' packages.txt)

for pkg in */; do
    pkg=${pkg%/}
    [[ $pkg == machines ]] && continue
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
