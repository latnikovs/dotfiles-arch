#!/usr/bin/env bash
# Jump to whatever was clicked on the status bar: an agent's dot, or a session
# name in the agents pill.
#
# The status formats wrap each clickable piece in `#[range=user|...]`, and tmux
# hands back the name of the range under the pointer as #{mouse_status_range}.
# Two shapes are published, both tmux ids so they are unambiguous and short
# enough for the 15-byte cap on a range name:
#
#   %12   a pane -- one specific agent, wherever it lives
#   $3    a session -- go to it as it is, on whatever window it left off
#
# Written as a script rather than `switch-client -t=` on a `range=pane`, which
# tmux has natively: the mouse target is resolved against the *clicking
# client's* session, so a clicked pane belonging to another session simply does
# not resolve -- and the agents in the other sessions are the whole point of the
# pill. Going by id sidesteps that.
#
# The client is passed in for the same reason it cannot be inferred: run-shell
# spawns this outside of any client, so a bare `tmux switch-client` would have
# to guess which of the kitty tabs was clicked, and would move the wrong session
# on the wrong screen.
set -u

client=${1:-}
target=${2:-}

# Clicking a stretch of bar with no range of ours under it: the pills either
# side, or the padding between them.
[ -n "$target" ] || exit 0

case "$target" in
%*)
	# A pane may be in another session, so this is a switch-client plus a
	# select-window plus a select-pane, not a single jump.
	session=$(tmux display-message -p -t "$target" '#{session_id}') || exit 0
	window=$(tmux display-message -p -t "$target" '#{window_id}') || exit 0
	tmux switch-client -c "$client" -t "$session" || exit 0
	tmux select-window -t "$window"
	tmux select-pane -t "$target"
	;;
*)
	tmux switch-client -c "$client" -t "$target"
	;;
esac
