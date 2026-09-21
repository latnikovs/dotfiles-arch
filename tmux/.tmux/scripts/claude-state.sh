#!/usr/bin/env bash
# Publishes what Claude Code is doing into the tmux window chip.
#
# Called from the Claude Code hooks in ~/.claude/settings.json, one invocation
# per event, with the state as $1:
#
#   busy   a turn is running        (UserPromptSubmit, Pre/PostToolUse)
#   idle   the turn finished        (Stop, SessionStart)
#   clear  no Claude here any more  (SessionEnd)
#   notify a Notification fired; which state that means is read off the event,
#          see below
#
# Notification covers two unrelated things: Claude asking for something (a
# permission prompt) and the nag that fires once the prompt has sat unanswered
# for a minute. Treating both as "wants you" meant a finished turn turned from
# done to asking a minute later, all on its own, and the one state that should
# make you get up stopped meaning anything. The event's own message separates
# them: the nag says it is waiting for input, and anything else is a question.
#
# The state is written as a *pane* option on the pane the hook ran in, which is
# what makes this cost nothing to display: tmux resolves #{@claude_state} in
# window-status-format against that window's active pane, so the chips read the
# value directly on redraw. No #() job, no polling, no state files to reap --
# the option dies with the pane.
#
# Hooks run in the Claude process's environment, so $TMUX_PANE is the pane it
# was started in even when the hook fires from a deeply nested shell.
#
# Every path exits 0: a hook that fails is reported to Claude as an error, and a
# status bar decoration is never worth interrupting a turn over.
set -u

state="${1:-}"

# Claude feeds the hook its event JSON on stdin. Drain it even when unused, so
# it never sees a closed pipe, and so the subagent check below has it.
input=""
if [ ! -t 0 ]; then
	input="$(cat 2>/dev/null || true)"
fi

# Subagent turns start and stop inside the main one. Letting them drive the
# chip would flip it to idle while the parent is still working.
case "$input" in
*'"agent_id"'*)
	case "$input" in
	*'"agent_id": null'* | *'"agent_id":null'*) ;;
	*) exit 0 ;;
	esac
	;;
esac

[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

# Resolve 'notify' before anything is written: an unrecognised message is
# treated as a question, since a notification Claude bothered to send is more
# likely to want something than not.
if [ "$state" = notify ]; then
	message="$(printf '%s' "$input" |
		sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
	case "$message" in
	*[Ww]aiting\ for\ your\ input*) state="idle" ;;
	# Quoted because `wait` is a shell builtin and an unquoted assignment of a
	# builtin's name reads as a command substitution typo (SC2209).
	*) state="wait" ;;
	esac
fi

case "$state" in
busy | wait | idle)
	tmux set-option -p -t "$TMUX_PANE" @claude_state "$state" 2>/dev/null || exit 0
	;;
clear)
	tmux set-option -p -u -t "$TMUX_PANE" @claude_state 2>/dev/null || exit 0
	;;
*)
	exit 0
	;;
esac

# The busy glyph animates, and an animation needs a clock tmux does not have;
# claude-spin.sh is that clock. It is a singleton and exits by itself once no
# pane is busy, so starting it on every busy event is the whole of the wiring.
#
# Fully detached, with all three fds closed off: it outlives this hook by
# design, and a hook that leaves a pipe open to a living child is a hook Claude
# waits on.
if [ "$state" = busy ]; then
	nohup "$(dirname "${BASH_SOURCE[0]}")/claude-spin.sh" \
		>/dev/null 2>&1 </dev/null &
	disown 2>/dev/null || true
fi

# status-interval is 5s; without this the chip would lag a turn ending by up to
# that long, which is exactly the moment the indicator exists for.
#
# Every client, not just this pane's: the agents pill in status-left reports on
# *other* sessions, so a state change here is news to every other kitty tab's
# status line. refresh-client with no -t only reaches the client tmux infers
# from this command's context, which leaves the tabs that actually needed
# telling waiting for their next tick.
tmux list-clients -F '#{client_name}' 2>/dev/null | while IFS= read -r client; do
	[ -n "$client" ] || continue
	tmux refresh-client -S -t "$client" 2>/dev/null || true
done
exit 0
