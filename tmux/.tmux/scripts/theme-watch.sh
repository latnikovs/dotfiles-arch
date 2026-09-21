#!/usr/bin/env bash
# Reloads tmux.conf when the OS appearance stops matching the loaded flavor.
#
# kitty repaints itself the moment macOS flips between light and dark; tmux has
# no such hook, so the status line calls this on every redraw and it reloads
# only on an actual mismatch. It prints nothing and occupies no columns: it is
# in the bar purely for the side effect.
#
# This converges: the reload re-runs flavor.sh through the if-shell in tmux.conf,
# which sets @catppuccin_flavor to the value we just read, so the next call is a
# no-op.
set -u

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

want="$("$dir/flavor.sh")"
have="$(tmux show -gqv @catppuccin_flavor 2>/dev/null)"

[ -n "$want" ] || exit 0
[ "$want" = "$have" ] && exit 0

# reload.sh, not source-file: the palette will not budge otherwise. See there.
"$dir/reload.sh" 2>/dev/null
exit 0
