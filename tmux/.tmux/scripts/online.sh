#!/usr/bin/env bash
# tmux status module: network reachability.
# Usage: online.sh <surface> <online-accent> <offline-accent>
#
# The probe result is cached, so the bar can redraw every few seconds without
# emitting a ping every few seconds.
set -u

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

surface="${1:-#363a4f}"
online="${2:-#8bd5ca}"
offline="${3:-#ed8796}"

cache="${TMPDIR:-/tmp}/tmux-online-status.$(id -u)"
ttl=30

probe() {
	case "$(uname -s)" in
		Darwin) ping -c1 -t1 1.1.1.1 >/dev/null 2>&1 ;;
		*) ping -c1 -W1 1.1.1.1 >/dev/null 2>&1 ;;
	esac
}

fresh=0
if [ -f "$cache" ]; then
	now="$(date +%s)"
	# stat is BSD on macOS, GNU elsewhere.
	mtime="$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null)"
	[ -n "$mtime" ] && [ "$((now - mtime))" -lt "$ttl" ] && fresh=1
fi

if [ "$fresh" -eq 1 ]; then
	state="$(cat "$cache")"
else
	if probe; then state=up; else state=down; fi
	printf '%s' "$state" >"$cache"
fi

if [ "$state" = up ]; then
	# Icon only: online is the boring case and does not need a word for it.
	# The md-wifi glyph's ink is wider than its cell, so with nothing after it
	# the right cap paints over the fan and clips it. A trailing space gives the
	# glyph a buffer column — the same room the labelled pills get for free.
	pill "$surface" "$online" "$ICO_WIFI" " "
else
	pill "$surface" "$offline" "$ICO_WIFI_OFF" " offline"
fi
