#!/usr/bin/env bash
# Background jobs for the agents: sets @claude_jobs on every pane running a
# Claude to the number of shells its Bash tool still has open, or unsets it.
# Prints nothing: a zero-width #() in status-left, like ws-git.sh, so it runs
# every status-interval.
#
# What it is for is a Claude that has finished its turn but is waiting on a
# command it sent to the background -- a test run, a build. Its hooks have
# nothing to say about that (Stop has fired, so the state is idle), and a
# command ending signals nobody, so this looks instead. The bar and the sidebar
# then draw that idle as 'jobs' (@claude_shown in tmux.conf).
#
# Claude's Bash tool runs every command, in the foreground or not, in a shell
# that is a direct child of Claude and sources one of its shell snapshots
# first, which is how they are told from its MCP servers and the like. Claude
# runs as the pane's process or as a child of the pane's shell.
#
# While Claude is busy the count includes the command it is running in the
# foreground; busy is drawn over it then, so that does not show.
set -u

changes=$(awk '
	FNR == NR {
		parent[$1] = $2
		if (index($0, "/.claude/shell-snapshots/")) shells[$2]++
		next
	}
	# The panes: id, pid, live, old count.
	{
		n = 0
		if ($3 == 1) for (c in shells) if (c == $2 || parent[c] == $2) n += shells[c]
		if (n == 0) n = ""
		if (n != $4) print $1 "\t" n
	}
' <(ps -e -o pid=,ppid=,args=) FS='\t' \
	<(tmux list-panes -a -F '#{pane_id}	#{pane_pid}	#{E:@claude_live}	#{@claude_jobs}'))

[ -n "$changes" ] || exit 0
while IFS=$'\t' read -r pane n; do
	if [ -n "$n" ]; then
		tmux set-option -p -t "$pane" @claude_jobs "$n"
	else
		tmux set-option -pu -t "$pane" @claude_jobs
	fi
done <<<"$changes"

# Redraw now rather than at the next interval: the sidebars, and every
# client's bar, as claude-state.sh does on a state change.
tmux wait-for -S sidebar
tmux list-clients -F '#{client_name}' | while read -r client; do
	tmux refresh-client -S -t "$client" 2>/dev/null || true
done
