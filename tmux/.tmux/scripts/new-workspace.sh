#!/usr/bin/env bash
# Prefix + N (or '+ new workspace' on the sidebar): pick a project and get a
# workspace for it -- a session named after the project, started in it.
#
# Projects are the git repositories under ~/Work (~/Work/<org>/<repo> and the
# like) plus ~/dotfiles. One that already has a workspace is marked, and picking
# it goes to that one instead of opening a second.
#
# Anything typed that matches no project makes a plain workspace of that name
# in ~/Work, which is what Prefix + N did before it picked projects.
#
# The client to switch is the one the popup is drawn on, which is what tmux
# answers from inside it (display-popup expands no formats in its command, so
# the binding can't pass it in).
# Usage: new-workspace.sh [client]
set -u

client=${1:-$(tmux display-message -p '#{client_name}')}

# The directory a project's workspace is known by is its session_path, so the
# mark and the reuse go by path, not by name: two repos called 'ui' in
# different orgs are two workspaces.
open=$(tmux list-sessions -F '#{session_path}')

projects=$({
	fd --hidden --no-ignore --type d --type f --max-depth 4 --prune '^\.git$' "$HOME/Work" \
		--exec dirname {} 2>/dev/null
	[ -d "$HOME/dotfiles" ] && echo "$HOME/dotfiles"
} | sort -u | while read -r dir; do
	mark=' '
	grep -qxF "$dir" <<<"$open" && mark='●'
	printf '%s\t%s %s\n' "$dir" "$mark" "${dir/#$HOME/\~}"
done)

# --print-query: the first line is what was typed, the second the pick, if any.
result=$(printf '%s\n' "$projects" | fzf --print-query --delimiter='\t' --with-nth=2 \
	--reverse --prompt='workspace > ' --header='● already open · no match: new workspace named as typed')
query=$(sed -n 1p <<<"$result")
dir=$(sed -n 2p <<<"$result" | cut -f1)

if [ -n "$dir" ]; then
	# Already open: go there.
	session=$(tmux list-sessions -F '#{session_id}	#{session_path}' |
		awk -F '\t' -v dir="$dir" '$2 == dir { print $1; exit }')
	if [ -z "$session" ]; then
		# Named after the repo; tmux reads '.' and ':' in a name as target
		# syntax. A name already taken by another path gets its org in front.
		name=$(basename "$dir" | tr '.:' '__')
		tmux has-session -t "=$name" 2>/dev/null &&
			name="$(basename "$(dirname "$dir")" | tr '.:' '__')-$name"
		session=$(tmux new-session -d -P -F '#{session_id}' -s "$name" -c "$dir") || exit 0
	fi
elif [ -n "$query" ]; then
	name=$(tr '.:' '__' <<<"$query")
	session=$(tmux new-session -d -P -F '#{session_id}' -s "$name" -c "$HOME/Work") || exit 0
else
	exit 0
fi

tmux switch-client -c "$client" -t "$session"
"$HOME/.tmux/scripts/sidebar.sh" unfocus "$client"
