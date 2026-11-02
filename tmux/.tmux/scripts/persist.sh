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
#
#   order     resurrect's post-save-all hook: puts the save's sessions in
#             workspace order
#
# The workspace order (sidebar, Alt + 1..9) is the order the sessions were made
# in; tmux has no other. Resurrect saves them by name and remakes them in the
# order the file lists them, so every restart came back alphabetical. After a
# save its pane lines -- the ones the restore makes sessions from -- are put in
# the order the sessions have now.
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
order)
	saves=$(tmux show-options -gqv @resurrect-dir)
	if [ -z "$saves" ]; then
		saves="$HOME/.tmux/resurrect"
		[ -d "$saves" ] || saves="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
	fi
	file=$(readlink -f "$saves/last") || exit 0
	[ -f "$file" ] || exit 0
	sessions=$(tmux display-message -p '#{S/i:#{session_name}	}')
	# Stable, so a session's panes keep their order; anything not in the list
	# (it cannot be, but) goes last. Other lines keep theirs.
	awk -F '\t' -v order="$sessions" '
		BEGIN { n = split(order, names, "\t"); for (i = 1; i <= n; i++) rank[names[i]] = i }
		$1 == "pane" { r = ($2 in rank) ? rank[$2] : n + 1; panes[r] = panes[r] $0 "\n"; next }
		{ rest = rest $0 "\n" }
		END { for (i = 1; i <= n + 1; i++) printf "%s", panes[i]; printf "%s", rest }
	' "$file" >"$file.tmp" && mv "$file.tmp" "$file"
	;;
esac
exit 0
