#!/usr/bin/env bash
# The workspaces kept across restarts, with tmux-resurrect doing the saving
# and restoring (claude-resume.sh and sidebar.sh hook into both, see tmux.conf):
#
#   save      a zero-width #() in status-left, so it runs every status-interval;
#             saves when the last save is $interval old
#   restore   at config load; restores the last save when the server has only
#             just started, and holds the first save back until then
#
# What tmux-continuum is for, without it: continuum turns both off when it
# counts more tmux processes than attached clients, taking that for a second
# server, and every sidebar waits in a `tmux wait-for` of its own. So it never
# saved, and restored only when it won the race with the first sidebar.
set -u

interval=$((15 * 60))
resurrect="$HOME/.tmux/plugins/tmux-resurrect/scripts"

now=$(date +%s)

case "${1:-}" in
save)
	last=$(tmux show-options -gqv @persist_last)
	[ "$now" -ge $((${last:-0} + interval)) ] || exit 0
	# Before the save, not after: the next status-interval's job would
	# otherwise start a second one while this one runs.
	tmux set-option -g @persist_last "$now"
	"$resurrect/save.sh" quiet >/dev/null 2>&1
	;;
restore)
	# On every load, the first included: a new server is one session in its
	# home directory, and saving that over the last save would lose it before
	# the restore below has put it back.
	[ -n "$(tmux show-options -gqv @persist_last)" ] || tmux set-option -g @persist_last "$now"

	started=$(tmux display-message -p '#{start_time}')
	[ "$started" -ge $((now - 10)) ] || exit 0
	[ -z "$(tmux show-options -gqv @persist_restored)" ] || exit 0
	tmux set-option -g @persist_restored 1
	# The config still loading (run-shell -b), and the session the server was
	# started for still being made: resurrect restores over that session only
	# once it exists, as the server's one pane.
	sleep 1
	"$resurrect/restore.sh"
	;;
esac
exit 0
