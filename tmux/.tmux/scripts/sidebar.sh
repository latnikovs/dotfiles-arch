#!/usr/bin/env bash
# The workspaces sidebar: a narrow pane down the left of every window listing
# each session (a workspace: one per project), the branch it
# is on and the Claudes in it, by state and conversation title. A click on a
# workspace or an agent goes there.
#
#   render                the sidebar itself, run in its pane by `ensure`
#   ensure <target>       give that window a sidebar if it has none
#   ensure-all            every window on the server
#   shown                 every window a client is showing, then signal
#   toggle                take them all down, or put them all back (Prefix + b)
#   tidy                  close windows left with nothing but their sidebar
#   click <client> <pane> <y> <x>   a mouse click on a sidebar, from MouseDown1Pane
#   unfocus <client>      move that client's focus off a sidebar onto its window
#   suspend | restored    around a tmux-resurrect restore, see below
#
# A pane rather than a status row because tmux bars are horizontal only. The
# pane is marked with the @sidebar pane option, which is how everything else --
# the pane border, the mouse bindings, the agent picker's jumps -- tells it
# from a real one.
#
# Drawing costs next to nothing while nothing happens. A sidebar only draws
# while it is on screen (its window is the current one of an attached session)
# and otherwise sleeps in `tmux wait-for sidebar`, which every event that
# changes what it shows signals: an agent changing state (claude-state.sh), a
# branch moving (ws-git.sh), sessions coming and going, a client switching
# window or session (the hooks in tmux.conf). One signal wakes all of them. On
# screen it also redraws every few seconds, for the terminal titles Claude
# renames its conversations by, which nothing signals.
set -u

width_default=26
script="$HOME/.tmux/scripts/sidebar.sh"

signal() { tmux wait-for -S sidebar 2>/dev/null || true; }

width() {
	local width
	width=$(tmux show-options -gqv @sidebar_width)
	echo "${width:-$width_default}"
}

ensure() {
	local target=$1
	[ -z "$(tmux show-options -gqv @sidebar_off)" ] || return 0
	[ -z "$(tmux show-options -gqv @sidebar_restoring)" ] || return 0
	tmux list-panes -t "$target" -F '#{@sidebar}' 2>/dev/null | grep -qx 1 && return 0
	local pane
	# -f -b: the whole height of the window, left of everything; -d: the
	# focus stays where it was.
	pane=$(tmux split-window -hbfd -l "$(width)" -t "$target" \
		-P -F '#{pane_id}' "exec '$script' render") || return 0
	tmux set-option -p -t "$pane" @sidebar 1 \; select-pane -t "$pane" -T sidebar
}

# One ensure at a time per server: a new session fires two hooks at once
# (session-created, and after-new-window for its window), and two checks that
# both find no sidebar add two.
locked() {
	local lock
	lock="${XDG_RUNTIME_DIR:-/tmp}/tmux-sidebar-$(tmux display-message -p '#{pid}').lock"
	flock "$lock" "$script" "$@"
}

# rgb <fg|bg> <#rrggbb>: the truecolor escape for it, or nothing for a value
# that is not a colour (a palette not loaded yet).
rgb() {
	[[ $2 == \#?????? ]] || return 0
	local layer=38
	[ "$1" = bg ] && layer=48
	printf '\033[%d;2;%d;%d;%dm' "$layer" "0x${2:1:2}" "0x${2:3:2}" "0x${2:5:2}"
}

render() {
	local pane=$TMUX_PANE
	# No cursor, no wrapping: a line too long for the pane is cut, not folded
	# onto the next one, which would throw the click map off.
	printf '\033[?25l\033[?7l'
	trap 'printf "\033[?25h\033[?7h"' EXIT

	local last="" panel=""
	while :; do
		local data
		# One call for everything: this pane's own size and visibility, the
		# glyphs and palette, then a line per session (S) and per live agent in
		# it (A), in the same index order the Alt + 1..9 numbers follow.
		data=$(tmux display-message -p -t "$pane" "#{pane_width}	#{pane_height}	#{session_id}	#{&&:#{window_active},#{session_attached}}	#{?@claude_spin,#{@claude_spin},#{@ico_claude_busy}}	#{?@claude_ring,#{@claude_ring},#{@ico_claude_wait}}	#{@ico_claude_idle}	#{@ico_claude_jobs}	#{@ico_branch}	#{@frame}	#{@thm_fg}	#{@thm_subtext_0}	#{@thm_overlay_1}	#{@dim}	#{@raise}	#{@thm_sky}	#{@icon_peach}	#{@icon_red}	#{@icon_green}	#{@icon_blue}
#{S/i:S	#{session_id}	#{session_name}	#{@ws_git}
#{W:#{P:#{?#{E:@claude_live},A	#{pane_id}	#{E:@claude_shown}	#{?#{&&:#{window_active},#{pane_active}},1,0}	#{pane_title}
,}}}}") || exit 0

		local width height own visible ico_busy ico_wait ico_idle ico_jobs ico_branch
		local c_mantle c_fg c_sub c_ov1 c_ov0 c_raise c_sky c_busy c_wait c_idle c_jobs
		IFS=$'\t' read -r width height own visible ico_busy ico_wait ico_idle ico_jobs ico_branch \
			c_mantle c_fg c_sub c_ov1 c_ov0 c_raise c_sky c_busy c_wait c_idle c_jobs <<<"${data%%$'\n'*}"

		# The pane is a panel: @frame, the colour the status bar is drawn in too,
		# so bar and sidebar read as one L around the work. Set as the pane's
		# own style, which every default-background cell takes, so it follows a
		# flavor flip without a redraw of its own.
		if [ -n "$c_mantle" ] && [ "$c_mantle" != "$panel" ]; then
			tmux set-option -p -t "$pane" window-style "bg=$c_mantle" \; \
				set-option -p -t "$pane" window-active-style "bg=$c_mantle"
			panel=$c_mantle
		fi

		if [ "$visible" != 1 ]; then
			# Off screen: nothing to keep fresh until something signals.
			tmux wait-for sidebar 2>/dev/null || exit 0
			continue
		fi
		# Back to its width whenever it is off it: tmux scales every pane when
		# the window resizes, and a window made in a detached session is 80
		# wide until a client attaches to it.
		if [ "$width" != "$(width)" ]; then
			tmux resize-pane -t "$pane" -x "$(width)"
			continue
		fi

		# The current workspace is a card: a band in @raise, the step up from
		# the panel the active tab uses too, with the accent down its left edge.
		local band=$c_raise
		local reset=$'\033[0m' bold=$'\033[1m' nobold=$'\033[22m'
		local f_fg f_sub f_ov1 f_ov0 f_sky b_band
		f_fg=$(rgb fg "$c_fg") f_sub=$(rgb fg "$c_sub") f_ov1=$(rgb fg "$c_ov1")
		f_ov0=$(rgb fg "$c_ov0") f_sky=$(rgb fg "$c_sky")
		b_band=$(rgb bg "$band")

		# Every line goes through row(), which keeps the click map in step
		# and stops at the bottom edge: a line past it would scroll the pane.
		local out="" map="" y=0
		# Lines are padded to the full width rather than ended with an erase:
		# tmux erases in the pane's style, not the current background, which
		# would cut the card's band off at the end of the text.
		row() { # row <text> [map-key...]
			[ "$y" -lt "$height" ] || return 0
			local plain=$1 pad
			while [[ $plain =~ ^(.*)$'\033'\[[0-9\;]*m(.*)$ ]]; do plain=${BASH_REMATCH[1]}${BASH_REMATCH[2]}; done
			pad=$((width - ${#plain}))
			out+="$1$(printf '%*s' "$((pad > 0 ? pad : 0))" '')$reset"$'\033[K\n'
			local key
			for key in "${@:2}"; do map+=" ${key//@/$y}"; done
			y=$((y + 1))
		}

		row ""
		row "  $f_ov0${bold}WORKSPACES$nobold"
		row ""

		# Sessions with their agents, gathered first: an agent's tree line
		# depends on whether another follows it.
		local -a s_id=() s_name=() s_branch=() s_agents=()
		local kind id name branch rest i=-1
		while IFS=$'\t' read -r kind id name branch rest; do
			case "$kind" in
			S)
				i=$((i + 1))
				s_id[i]=$id s_name[i]=$name s_branch[i]=${branch# } s_agents[i]=""
				;;
			A) [ "$i" -ge 0 ] && s_agents[i]+="$id"$'\t'"$name"$'\t'"$branch"$'\t'"$rest"$'\n' ;;
			esac
		done <<<"${data#*$'\n'}"

		# An agent busy or waiting animates (claude-spin.sh keeps the frame),
		# so while there is one the sidebar redraws a few times a second
		# instead of every five. A pass costs ~10ms.
		local nap=5
		[[ ${data#*$'\n'} =~ $'\t'(busy|wait)$'\t' ]] && nap=0.3

		local n edge bg num_fg name_fg line pad label agents count k state active title glyph colour tree title_fg
		for ((n = 0; n <= i; n++)); do
			id=${s_id[n]} name=${s_name[n]:0:$((width - 8))} branch=${s_branch[n]}
			label=$((n + 1))
			line=""
			if [ "$id" = "$own" ]; then
				bg=$b_band edge="$f_sky▌" num_fg=$f_sky name_fg="$f_fg$bold"
				# The close button, on the current workspace only, a column in
				# from the right edge; the 'x' entry in the map is the click
				# that lands on it. Elsewhere those columns are the row's.
				pad=$((width - 2 - (3 + ${#label} + ${#name})))
				line=$(printf '%*s%s×' "$((pad > 0 ? pad : 0))" '' "$f_ov1")
			else
				bg="" edge=" " num_fg=$f_ov0 name_fg=$f_sub
			fi
			line="$bg$edge $num_fg$label $name_fg$name$nobold$line"
			if [ "$id" = "$own" ]; then
				row "$line" "@=$id" "x@=$id"
			else
				row "$line" "@=$id"
			fi
			# The branch and the agents hang off the number's column, so their
			# text lines up under the workspace name.
			[ -n "$branch" ] && row "$bg$edge $f_ov0$ico_branch $f_ov1${branch:0:$((width - 6))}" "@=$id"

			agents=${s_agents[n]%$'\n'}
			if [ -n "$agents" ]; then
				count=$(grep -c '' <<<"$agents") k=0
				while IFS=$'\t' read -r id state active title; do
					k=$((k + 1))
					tree="├"
					[ "$k" = "$count" ] && tree="╰"
					# The same accents as the dots on the window tabs.
					case "$state" in
					busy) glyph=$ico_busy colour=$c_busy ;;
					wait) glyph=$ico_wait colour=$c_wait ;;
					jobs) glyph=$ico_jobs colour=$c_jobs ;;
					*) glyph=$ico_idle colour=$c_idle ;;
					esac
					# Claude puts its own state glyph in front of the title.
					title=$(sed -E 's/^[^[:alnum:]]+ //' <<<"$title")
					title=${title:0:$((width - 7))}
					# The agent you are in, in this workspace: bright.
					title_fg=$f_sub
					[ "${s_id[n]}" = "$own" ] && [ "$active" = 1 ] && title_fg="$f_fg$bold"
					row "$bg$edge $f_ov0$tree $(rgb fg "$colour")$glyph $title_fg$title$nobold" "@=$id"
				done <<<"$agents"
			fi
		done

		# Room permitting, a way in for the mouse to the project picker, set
		# off from the list by a blank line.
		if [ $((y + 2)) -lt "$height" ]; then
			row ""
			row "  $f_sky+ ${f_ov1}new workspace" "@=new"
		fi

		if [ "$out" != "$last" ]; then
			printf '\033[H%s\033[J' "$out"
			tmux set-option -p -t "$pane" @sidebar_map "$map"
			last=$out
		fi
		timeout "$nap" tmux wait-for sidebar 2>/dev/null
	done
}

# The window the client is on, and the pane in it to land on: whichever is
# right of the sidebar, when the sidebar has the focus.
unfocus() {
	local client=$1 window sidebar
	IFS=$'\t' read -r window sidebar < <(tmux display-message -p -c "$client" '#{window_id}	#{@sidebar}')
	[ "$sidebar" = 1 ] && tmux select-pane -t "$window" -R
	return 0
}

case "${1:-}" in
render) render ;;
ensure) locked _ensure "${2:-}" ;;
_ensure) ensure "${2:-}" ;;
ensure-all) locked _ensure-all ;;
_ensure-all)
	tmux list-windows -a -F '#{window_id}' | while read -r window; do ensure "$window"; done
	;;
shown)
	# Whatever a client is looking at has a sidebar, and every sidebar hears
	# about it. On attaching and on switching window or session, which also
	# catches what the other hooks can miss: the first session of a new server
	# is made before its config's hooks are in place.
	tmux list-clients -F '#{window_id}' | sort -u | while read -r window; do
		locked _ensure "$window"
	done
	signal
	;;
toggle)
	if [ -z "$(tmux show-options -gqv @sidebar_off)" ]; then
		tmux set-option -g @sidebar_off 1
		tmux list-panes -a -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 { print $1 }' |
			while read -r pane; do tmux kill-pane -t "$pane"; done
	else
		tmux set-option -gu @sidebar_off
		"$script" ensure-all
	fi
	;;
tidy)
	# A window whose last real pane has gone: close it, as tmux would have had
	# the sidebar not been there.
	tmux list-windows -a -F '#{window_id} #{window_panes}' | while read -r window panes; do
		[ "$panes" = 1 ] || continue
		[ "$(tmux display-message -p -t "$window" '#{@sidebar}')" = 1 ] && tmux kill-window -t "$window"
	done
	signal
	;;
click)
	client=${2:-} pane=${3:-} y=${4:-} x=${5:-0}
	read -r width map < <(tmux display-message -p -t "$pane" '#{pane_width} #{@sidebar_map}')
	# The last three columns of a workspace line are its close button, whose
	# entries in the map are keyed 'x<line>'.
	key=$y
	[ "$x" -ge $((width - 3)) ] && [[ " $map " == *" x$y="* ]] && key=x$y
	target=""
	for entry in $map; do
		[ "${entry%%=*}" = "$key" ] && target=${entry#*=}
	done
	[ -n "$target" ] || exit 0
	if [ "$key" != "$y" ]; then
		# Closing kills what runs in it, agents included, so it asks first. In
		# a popup, as Prefix + N used to ask for a name: status-justify
		# 'centre' splits tmux's own prompt across the bar.
		tmux display-popup -c "$client" -w 52 -h 3 -x C -y C -E "$script _close '$target'"
		exit 0
	fi
	case "$target" in
	new)
		tmux display-popup -c "$client" -w 60% -h 60% -x C -y C -E \
			"$HOME/.tmux/scripts/new-workspace.sh '$client'"
		;;
	%*) "$HOME/.tmux/scripts/goto-agent.sh" "$client" "$target" ;;
	*)
		tmux switch-client -c "$client" -t "$target"
		unfocus "$client"
		;;
	esac
	;;
_close)
	# Runs in the confirmation popup. A client on the closed workspace moves
	# to the one it used before (detach-on-destroy in tmux.conf).
	session=${2:-}
	IFS=$'\t' read -r name agents < <(tmux display-message -p -t "$session" \
		'#{session_name}	#{W:#{P:#{?#{E:@claude_live},x,}}}')
	[ -n "$name" ] || exit 0
	what="Close $name?"
	[ -n "$agents" ] && what="Close $name and its ${#agents} agent(s)?"
	printf ' %s [y/N] ' "$what"
	read -rsn1 answer
	case "$answer" in
	y | Y) tmux kill-session -t "$session" ;;
	esac
	;;
unfocus) unfocus "${2:-}" ;;
signal) signal ;;
suspend)
	# Resurrect brings the sidebars back as plain shell panes, titled
	# 'sidebar' (it restores titles), and creates its windows through the
	# hooks that would hand each one a new sidebar on top. So none are added
	# while it works, and the placeholders go once it is done -- after
	# claude-resume.sh, whose pane indexes count them.
	#
	# The live ones go first: resurrect replaces the first session of a new
	# server with the saved ones only when that is the server's one pane, and
	# its sidebar would make it two.
	tmux set-option -g @sidebar_restoring 1
	tmux list-panes -a -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 { print $1 }' |
		while read -r pane; do tmux kill-pane -t "$pane"; done
	;;
restored)
	tmux list-panes -a -F '#{pane_id}	#{pane_title}	#{@sidebar}' |
		awk -F '\t' '$2 == "sidebar" && $3 != 1 { print $1 }' |
		while read -r pane; do tmux kill-pane -t "$pane"; done
	tmux set-option -gu @sidebar_restoring
	"$script" ensure-all
	;;
esac
exit 0
