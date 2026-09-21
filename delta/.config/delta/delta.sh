#!/usr/bin/env sh
# Run delta in the light/dark mode matching the current OS appearance, so its
# diffs match the active Catppuccin flavor (Latte when light, Macchiato when
# dark) — the same rule kitty and btop follow.
#
# delta auto-detects the terminal background only when it writes to a tty. Under
# lazygit (and any pipe) that detection fails and delta falls back to dark, which
# looks wrong on a light terminal. Probing the OS appearance instead works in
# every context, so this wrapper is used as both git's core.pager and lazygit's
# pager. Arguments are forwarded, so callers can still add e.g. --paging=never.
#
# flavor.sh is the shared appearance probe (also used by btop and the tmux bar);
# latte => --light, macchiato => --dark. If it is missing, fall back to plain
# delta and let delta decide.
set -u

flavor="$("$HOME/.tmux/scripts/flavor.sh" 2>/dev/null || true)"

case "$flavor" in
	latte) exec delta --light "$@" ;;
	macchiato) exec delta --dark "$@" ;;
	*) exec delta "$@" ;;
esac
