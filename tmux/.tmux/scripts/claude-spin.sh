#!/usr/bin/env bash
# Animates the busy glyph on the Claude Code chips, for as long as any Claude
# on this tmux server is mid-turn.
#
# Started by claude-state.sh on the busy transition; exits on its own once no
# pane reports busy any more. One instance per tmux server, guarded by the
# @claude_spin_pid server option.
#
# Why a process at all: the rest of the chip is pure format, resolved by tmux on
# redraw at no cost (see claude-state.sh). An animation needs a clock, and the
# format language has none -- every time-valued variable (client_activity,
# session_activity, window_activity) is an *event* timestamp, not now, and a
# status redraw does not touch them. So the frame has to be pushed in from
# outside, and the only question is what it costs. Here it costs nothing at all
# while you are not waiting on a turn, which is nearly always.
#
# What it buys over the static clock: liveness. Colour and shape already say
# busy; only motion separates "still working" from "wedged".
set -u

[ -n "${TMUX:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

# Frames: md-circle_slice_1..8, a pie filling clockwise. Deliberately the same
# circle silhouette as the wait and idle glyphs -- the three states stay three
# values of one thing rather than three unrelated pictures, and the interior
# still carries the meaning where the mauve badge starves the colour.
#
# \U escapes, not pasted glyphs, for the reason lib.sh gives: private-use
# codepoints are invisible in a diff and easy for tooling to drop.
frames=(
	$'\U000f0a9e' $'\U000f0a9f' $'\U000f0aa0' $'\U000f0aa1'
	$'\U000f0aa2' $'\U000f0aa3' $'\U000f0aa4' $'\U000f0aa5'
)

# 8 frames at 150ms is a 1.2s revolution: fast enough to read as motion, slow
# enough that the bar is not visibly churning in the corner of your eye.
interval=0.15

# Re-asking tmux which panes are busy is the expensive part of a tick, so it
# happens every RECHECK frames rather than every one. The lag that adds at the
# end of a turn is invisible: claude-state.sh refreshes the clients itself on
# the idle transition, and the idle glyph does not come from here.
RECHECK=4

# Singleton. A pid left behind by a kill -9 is not a lock, so a recorded pid
# that no longer exists is ignored.
running="$(tmux show -gqv @claude_spin_pid 2>/dev/null)"
if [ -n "$running" ] && kill -0 "$running" 2>/dev/null; then
	exit 0
fi

tmux set -g @claude_spin_pid "$$" 2>/dev/null || exit 0

# Two hooks firing busy at once can both get past the check above. Neither can
# win the option twice, so the loser sees someone else's pid here and leaves.
if [ "$(tmux show -gqv @claude_spin_pid 2>/dev/null)" != "$$" ]; then
	exit 0
fi

cleanup() {
	# Only if we are still the registered ticker: a successor that took over
	# after a stale-pid check must not have its registration unset by us.
	if [ "$(tmux show -gqv @claude_spin_pid 2>/dev/null)" = "$$" ]; then
		tmux set -gu @claude_spin_pid 2>/dev/null
	fi
	tmux set -gu @claude_spin 2>/dev/null
	exit 0
}
trap cleanup EXIT INT TERM

i=0
tick=0
while :; do
	if [ $((tick % RECHECK)) -eq 0 ]; then
		# The semver-argv0 match is the same crash guard @claude_live uses in
		# tmux.conf, and it matters more here than there. A busy left behind by
		# a Claude that died before its SessionEnd ran is merely invisible on
		# the chip; here it would be a pane that never stops being busy, and a
		# ticker that never stops ticking.
		out="$(tmux list-panes -a -F \
			'#{?#{&&:#{m:[0-9]*.[0-9]*.[0-9]*,#{pane_current_command}},#{==:#{@claude_state},busy}},busy,}' \
			2>/dev/null)" || cleanup

		case $'\n'"$out" in
		*$'\nbusy'*) ;;
		*) cleanup ;;
		esac
	fi

	# Setting the option is the whole repaint: set-option redraws every
	# client by itself. No refresh-client, with or without -S. Both make tmux
	# kill any #() job still running and start it over, and status.sh takes
	# ~200ms, longer than a frame -- so while a turn ran it never finished and
	# the right side of the bar went blank.
	tmux set -g @claude_spin "${frames[i]}" 2>/dev/null || cleanup

	i=$(((i + 1) % ${#frames[@]}))
	tick=$((tick + 1))
	sleep "$interval"
done
