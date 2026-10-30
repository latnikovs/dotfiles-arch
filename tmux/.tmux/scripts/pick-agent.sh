#!/usr/bin/env bash
# Keyboard way to the agents: Prefix + a lists every Claude on the server in a
# popup, with what it is showing on the right, and Enter jumps to it.
#
# The same agents the bar draws: panes with a @claude_state (published by
# claude-state.sh) whose command is still Claude: the @claude_live format in
# tmux.conf. A state left behind by a Claude that died
# without SessionEnd is dropped the same way.
#
# Each is listed by the title Claude gives its terminal, the conversation's
# name ('Ship.yml workflow PR'), less the state glyph in front of it.
#
# Ordered by what wants you: asking first, then finished, then finished but
# with a background command still running, then still working.
# Within a state the server's own order is kept, so the list doesn't reshuffle
# between two presses.
#
# The jump goes through goto-agent.sh, which wants the client to move. Asked
# for from inside the popup, tmux names the one it is drawn on; display-popup
# expands no formats in its command, so the binding can't pass it in.
set -u

client=${1:-$(tmux display-message -p '#{client_name}')}

agents=$(tmux list-panes -a -F \
	'#{pane_id}	#{E:@claude_shown}	#{E:@claude_live}	#{session_name}:#{window_index}	#{pane_title}' |
	awk -F '\t' '
		$3 == 1 {
			rank = $2 == "wait" ? 0 : $2 == "idle" ? 1 : $2 == "jobs" ? 2 : 3
			# The terminal 16 colours, so the list follows the Nord flavor
			colour = $2 == "wait" ? 31 : $2 == "idle" ? 32 : $2 == "jobs" ? 34 : 33
			title = $5
			sub(/^[^A-Za-z0-9]+ /, "", title)
			printf "%d\t%s\t\033[%dm%-4s\033[0m\t%-20s\t%s\n", rank, $1, colour, $2, $4, title
		}' |
	sort -s -t "$(printf '\t')" -k1,1n |
	cut -f2-)

if [ -z "$agents" ]; then
	tmux display-message -c "$client" "No agents running"
	exit 0
fi

# The pane id stays in field 1 for the preview and the jump, out of sight.
pane=$(printf '%s\n' "$agents" | fzf --ansi --delimiter='\t' --with-nth=2.. \
	--reverse --no-sort --prompt='agent > ' \
	--preview='tmux capture-pane -ep -t {1}' --preview-window='right,65%,follow' |
	cut -f1)

[ -n "$pane" ] || exit 0
exec "$(dirname "${BASH_SOURCE[0]}")/goto-agent.sh" "$client" "$pane"
