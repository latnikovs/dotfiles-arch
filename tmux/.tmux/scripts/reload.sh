#!/usr/bin/env bash
# Reload tmux.conf, including a switch between light and dark.
#
# The plugin publishes its palette with `set -ogq`, and -o means "do not touch
# an option that already exists". So once @thm_* is populated it is frozen for
# the life of the server: sourcing the other mode's palette file is a silent
# no-op, and a plain `source-file` leaves the bar on the old flavor's colors
# forever, however many times it runs. Only a fresh server would pick the change
# up, which is exactly the case that never happens on a machine that keeps tmux
# running for weeks.
#
# Dropping the palette first lets the plugin repopulate it for whatever
# flavor.sh now resolves.
#
# One reload at a time. A light/dark switch asks for two at once -- the theme
# script reloads straight away, and theme-watch.sh, seeing the old mode for
# as long as the first is under way, starts another -- and two interleaved
# reloads leave the bar broken: one drops the palette while the other derives
# the pills from it, and status-left, emptied and then appended to by each,
# ends up with its pieces twice. --if-idle (theme-watch.sh) skips instead of
# waiting, as the reload already running sets the new mode.
# Usage: reload.sh [--if-idle]
set -u

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-reload-$(tmux display-message -p '#{pid}').lock"
if [ "${1:-}" = --if-idle ]; then
	flock -n 9 || exit 0
else
	flock 9
fi

while read -r opt; do
	[ -n "$opt" ] && tmux set -gu "$opt"
done < <(tmux show -g | sed -n 's/^\(@thm_[a-z0-9_]*\) .*/\1/p')

tmux source-file "${TMUX_CONF:-$HOME/.tmux.conf}"
