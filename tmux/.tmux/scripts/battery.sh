#!/usr/bin/env bash
# tmux status module: battery charge and charging state.
# Usage: battery.sh <surface> <ok-accent> <warn-accent> <low-accent>
# Prints nothing on a machine with no battery (desktop, VM, most servers).
set -u

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

surface="${1:-#363a4f}"
ok="${2:-#a6da95}"
warn="${3:-#eed49f}"
low="${4:-#ed8796}"

pct='' charging=0

case "$(uname -s)" in
	Darwin)
		# 'Now drawing from ...' then e.g.
		#  -InternalBattery-0 (id=123)	79%; AC attached; not charging present: true
		batt="$(pmset -g batt 2>/dev/null)" || exit 0
		[[ "$batt" == *InternalBattery* ]] || exit 0
		pct="$(printf '%s' "$batt" | grep -o '[0-9]\{1,3\}%' | head -1 | tr -d '%')"
		# 'AC attached' without 'charging' means plugged in but holding, which
		# reads as charging for a status bar's purposes.
		[[ "$batt" == *"AC Power"* ]] && charging=1
		;;
	Linux)
		for d in /sys/class/power_supply/BAT*; do
			[ -r "$d/capacity" ] || continue
			pct="$(cat "$d/capacity")"
			[ "$(cat "$d/status" 2>/dev/null)" = Discharging ] || charging=1
			break
		done
		;;
esac

[ -n "$pct" ] || exit 0

# md-battery-10 .. md-battery-90 are consecutive from U+F007A, with the full
# cell at U+F0079 and the alert cell at U+F0083. See lib.sh on why these are
# escapes rather than literals.
ramp=(
	$'\U000f007a' $'\U000f007b' $'\U000f007c' $'\U000f007d' $'\U000f007e'
	$'\U000f007f' $'\U000f0080' $'\U000f0081' $'\U000f0082' $'\U000f0079'
)

if [ "$charging" -eq 1 ]; then
	icon=$'\U000f0084' # md-battery-charging
	accent="$ok"
elif [ "$pct" -le 10 ]; then
	icon=$'\U000f0083' # md-battery-alert
	accent="$low"
else
	# 11-20% -> ramp[0], ... 91-100% -> ramp[9]
	idx=$(((pct - 1) / 10))
	[ "$idx" -gt 9 ] && idx=9
	icon="${ramp[$idx]}"
	if [ "$pct" -le 20 ]; then
		accent="$low"
	elif [ "$pct" -le 35 ]; then
		accent="$warn"
	else
		accent="$ok"
	fi
fi

# 3 columns, so the width stays fixed: a pill that changes width drags the
# centred window list with it.
pill "$surface" "$accent" "$icon" "$(printf '%3d%%' "$pct")"
