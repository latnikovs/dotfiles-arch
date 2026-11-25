#!/usr/bin/env bash
# Animates the Claude Code state glyphs on the window tabs and the sidebar, for
# as long as any Claude on this tmux server is mid-turn (a twinkling star in
# @claude_spin) or waiting on you (a ringing bell in @claude_ring).
#
# Started by claude-state.sh on the busy and wait transitions; exits on its own
# once no pane is either. One instance per tmux server, guarded by the
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
# What it buys: liveness. Colour and shape already say busy; only motion
# separates "still working" from "wedged". And a bell that rings is hard to
# miss in the corner of your eye, which is the point of the wait state.
set -u

[ -n "${TMUX:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

# Busy frames: Claude Code's own spinner, a star growing points and shrinking
# back, so the tab twinkles in step with what the agent's pane shows. Plain
# Unicode (the font fallback draws them), so no escapes needed.
frames=('·' '✢' '✳' '✶' '✻' '✽' '✻' '✶' '✳' '✢')

# Wait frames: the bell rings, then rests. md-bell_ring and md-bell, as \U
# escapes for the reason lib.sh gives.
ring=($'\U000f009e' $'\U000f009a')

# 150ms a frame while anything is busy: a 1.5s twinkle. With only bells to
# ring, 300ms, as there is nothing quicker to keep up with.
interval_busy=0.15
interval_wait=0.3
# Ticks per bell frame: ~600ms ring, ~600ms rest either way.
RING_BUSY=4
RING_WAIT=2

# Re-asking tmux which panes are busy or waiting is the expensive part of a tick, so it
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
	tmux set -gu @claude_spin \; set -gu @claude_ring 2>/dev/null
	exit 0
}
trap cleanup EXIT INT TERM

i=0
tick=0
busy=0 waiting=0
while :; do
	if [ $((tick % RECHECK)) -eq 0 ]; then
		# @claude_live from tmux.conf: its command check is the crash guard, and
		# it matters more here than on the bar. A state left behind by a Claude
		# that died before its SessionEnd ran is merely invisible on the tab;
		# here it would be a pane that never stops being busy, and a ticker
		# that never stops ticking.
		out="$(tmux list-panes -a -F \
			'#{?#{E:@claude_live},#{@claude_state},}' \
			2>/dev/null)" || cleanup

		busy=0 waiting=0
		case $'\n'"$out"$'\n' in *$'\nbusy\n'*) busy=1 ;; esac
		case $'\n'"$out"$'\n' in *$'\nwait\n'*) waiting=1 ;; esac
		[ $((busy + waiting)) -gt 0 ] || cleanup
	fi

	# Setting the options is the whole repaint: set-option redraws every
	# client by itself. No refresh-client, with or without -S. Both make tmux
	# kill any #() job still running and start it over, and status.sh takes
	# ~200ms, longer than a frame -- so while a turn ran it never finished and
	# the right side of the bar went blank.
	if [ "$busy" = 1 ]; then
		interval=$interval_busy per=$RING_BUSY
		spin=(set -g @claude_spin "${frames[i % ${#frames[@]}]}")
	else
		interval=$interval_wait per=$RING_WAIT
		spin=(set -gu @claude_spin)
	fi
	if [ "$waiting" = 1 ]; then
		bell=(set -g @claude_ring "${ring[(tick / per) % ${#ring[@]}]}")
	else
		bell=(set -gu @claude_ring)
	fi
	tmux "${spin[@]}" \; "${bell[@]}" 2>/dev/null || cleanup

	i=$((i + 1))
	tick=$((tick + 1))
	sleep "$interval"
done
