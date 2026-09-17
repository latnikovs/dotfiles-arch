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
