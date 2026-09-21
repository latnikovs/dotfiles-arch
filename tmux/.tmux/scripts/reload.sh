#!/usr/bin/env bash
# Reload tmux.conf, including a change of Catppuccin flavor.
#
# The plugin publishes its palette with `set -ogq`, and -o means "do not touch
# an option that already exists". So once @thm_* is populated it is frozen for
# the life of the server: sourcing the other flavor's theme file is a silent
# no-op, and a plain `source-file` leaves the bar on the old flavor's colors
# forever, however many times it runs. Only a fresh server would pick the change
# up, which is exactly the case that never happens on a machine that keeps tmux
# running for weeks.
#
# Dropping the palette first lets the plugin repopulate it for whatever
# flavor.sh now resolves.
set -u

while read -r opt; do
	[ -n "$opt" ] && tmux set -gu "$opt"
done < <(tmux show -g | sed -n 's/^\(@thm_[a-z0-9_]*\) .*/\1/p')

tmux source-file "${TMUX_CONF:-$HOME/.tmux.conf}"
