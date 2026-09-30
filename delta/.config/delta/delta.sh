#!/usr/bin/env sh
# Run delta in the light/dark mode matching the current OS appearance, with the
# Nord syntax theme in dark mode (bat has no Nord light; OneHalfLight is close).
#
# delta auto-detects the terminal background only when it writes to a tty. Under
# lazygit (and any pipe) that detection fails and delta falls back to dark, which
# looks wrong on a light terminal. Probing the OS appearance instead works in
# every context, so this wrapper is used as both git's core.pager and lazygit's
# pager. Arguments are forwarded, so callers can still add e.g. --paging=never.
#
# flavor.sh is the shared appearance probe (also used by the tmux bar). If it is
# missing, fall back to plain delta and let delta decide.
set -u

flavor="$("$HOME/.tmux/scripts/flavor.sh" 2>/dev/null || true)"

case "$flavor" in
	light) exec delta --light --syntax-theme OneHalfLight "$@" ;;
	dark) exec delta --dark --syntax-theme Nord "$@" ;;
	*) exec delta "$@" ;;
esac
