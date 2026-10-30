#!/usr/bin/env bash
# Alt + 1..9: go to that workspace, numbered as the sidebar numbers its
# workspaces -- sessions in index order, which is the order they were created in.
# Usage: goto-workspace.sh <client> <number>
#
# The client is passed in for the reason goto-agent.sh gives: run-shell runs
# outside of one.
set -u

client=${1:-}
number=${2:-}

read -r -a sessions <<<"$(tmux display-message -p '#{S/i:#{session_id} }')"
[ "$number" -ge 1 ] 2>/dev/null && [ "$number" -le "${#sessions[@]}" ] || exit 0
tmux switch-client -c "$client" -t "${sessions[number - 1]}"
"$(dirname "${BASH_SOURCE[0]}")/sidebar.sh" unfocus "$client"
