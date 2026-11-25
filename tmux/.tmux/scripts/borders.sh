#!/usr/bin/env bash
# Border lines only where there are panes to divide: a window with two or more
# real panes (the sidebar does not count) draws its borders as lines, one with
# a single pane as blank space.
#
# The single pane's only border is the column beside the sidebar, drawn in the
# frame colour on the frame colour. kitty makes that background a little
# see-through (transparent_background_colors) but draws the line glyph opaque,
# which left a hairline down the sidebar's edge.
#
# Usage: borders.sh [window]   (no window: every window on the server)
# Run from the window-layout-changed hook, which every split, close, zoom and
# sidebar toggle passes through, and on config load.
set -u

fmt='#{window_id}	#{window_panes}	#{P:#{?#{@sidebar},s,}}	#{pane-border-lines}'
if [ -n "${1:-}" ]; then
	list=$(tmux display-message -p -t "$1" "$fmt" 2>/dev/null) || exit 0
else
	list=$(tmux list-windows -a -F "$fmt")
fi

while IFS=$'\t' read -r window panes sidebars lines; do
	[ -n "$window" ] || continue
	want=spaces
	[ $((panes - ${#sidebars})) -gt 1 ] && want=single
	[ "$lines" = "$want" ] || tmux set-option -w -t "$window" pane-border-lines "$want"
	# Title rows came and went with splits before; none any more.
	tmux set-option -w -u -t "$window" pane-border-status 2>/dev/null
done <<<"$list"
exit 0
