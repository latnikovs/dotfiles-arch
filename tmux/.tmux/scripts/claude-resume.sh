#!/usr/bin/env bash
# Brings each Claude back into its pane after tmux-resurrect restores the
# server, with the conversation it was in.
#
#   save     resurrect's post-save-all hook: writes down every live Claude as
#            session, window, pane, conversation id and permission mode
#   restore  resurrect's post-restore-all hook: runs `claude --resume` in each
#            of those panes
#
# Resurrect restores the panes but not the programs it doesn't know, and Claude
# can't be one of them: it overwrites its argv0 with a bare version string, so
# what resurrect would save as its command line is '2.1.212'. The conversation
# id and mode come from claude-state.sh, which keeps them in pane options.
#
# Panes are matched by session name and window and pane index, which resurrect
# restores as they were. A pane that isn't back at a plain shell is left alone,
# so nothing gets typed into whatever else is running there.
set -u

list="${XDG_STATE_HOME:-$HOME/.local/state}/tmux/claude-sessions"

case "${1:-}" in
save)
	mkdir -p "$(dirname "$list")"
	# Live by the @claude_live format in tmux.conf: a state was reported and
	# the pane is still running Claude.
	tmux list-panes -a -F \
		'#{session_name}	#{window_index}	#{pane_index}	#{@claude_session}	#{@claude_mode}	#{E:@claude_live}' |
		awk -F '\t' '$4 != "" && $6 == 1 { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 }' \
			>"$list.new" && mv "$list.new" "$list"
	;;
restore)
	[ -f "$list" ] || exit 0
	while IFS=$'\t' read -r session window pane id mode; do
		target="=$session:$window.$pane"
		command=$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null) || continue
		case "$command" in
		zsh | bash | sh) ;;
		*) continue ;;
		esac
		# The panes were only just created, and keys sent before the shell has
		# drawn its prompt lose their first characters to its startup. Up to 5s
		# each, which runs concurrently with the others coming up.
		for _ in $(seq 50); do
			tmux capture-pane -p -t "$target" 2>/dev/null | grep -q '[^[:space:]]' && break
			sleep 0.1
		done
		tmux send-keys -t "$target" -l "claude --resume $id${mode:+ --permission-mode $mode}"
		tmux send-keys -t "$target" Enter
	done <"$list"
	;;
esac
exit 0
