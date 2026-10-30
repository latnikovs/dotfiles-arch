#!/usr/bin/env bash
# Branches for the sidebar: sets @ws_git on every session to ' main',
# with '*' when the tree has changes, or to nothing outside a work tree. Prints
# nothing itself: it runs as a zero-width #() in status-left, and the sidebars
# read the option.
#
# One job for every session rather than a #() per session. tmux does run one
# per distinct command, but a job that printed nothing (a session outside any
# repo) blanked the others' output with it, so branches came and went with
# whatever else was open.
set -u

changed=0
while IFS=$'\t' read -r session path old; do
	branch=""
	if cd "$path" 2>/dev/null; then
		branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" ||
			branch="$(git rev-parse --short HEAD 2>/dev/null)" ||
			branch=""
	fi
	value=""
	if [ -n "$branch" ]; then
		# Ticket-style branches would make one chip half the row.
		[ "${#branch}" -gt 20 ] && branch="${branch:0:19}…"
		# --no-optional-locks for the reason git.sh gives: a status every
		# interval would otherwise take index.lock out from under a commit.
		dirty=""
		[ -n "$(git --no-optional-locks status --porcelain 2>/dev/null | head -1)" ] && dirty="*"
		value=" $branch$dirty"
	fi
	[ "$value" = "$old" ] && continue
	tmux set-option -t "$session" @ws_git "$value"
	changed=1
done < <(tmux list-sessions -F '#{session_id}	#{session_path}	#{@ws_git}')

# Only when something moved: wakes the sidebars, which otherwise only pick it
# up on their next timed redraw.
[ "$changed" = 1 ] || exit 0
tmux wait-for -S sidebar
