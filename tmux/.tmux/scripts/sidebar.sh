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

render() {
	local pane=$TMUX_PANE
	# No cursor, no wrapping: a line too long for the pane is cut, not folded
	# onto the next one, which would throw the click map off.
	printf '\033[?25l\033[?7l'
	trap 'printf "\033[?25h\033[?7h"' EXIT

	local last=""
	while :; do
		local data
		# One call for everything: this pane's own size and visibility, then a
		# line per session (S) and per live agent in it (A), in the same index
		# order the Alt + 1..9 numbers follow.
		data=$(tmux display-message -p -t "$pane" "#{pane_width}	#{pane_height}	#{session_id}	#{&&:#{window_active},#{session_attached}}	#{@ico_claude_busy}	#{@ico_claude_wait}	#{@ico_claude_idle}	#{@ico_claude_jobs}	#{@theme_mode}	#{@thm_surface_1}	#{@thm_blue}
#{S/i:S	#{session_id}	#{session_name}	#{@ws_git}
#{W:#{P:#{?#{E:@claude_live},A	#{pane_id}	#{E:@claude_shown}	#{pane_title}
,}}}}") || exit 0

		local width height own visible ico_busy ico_wait ico_idle ico_jobs mode band accent
		IFS=$'\t' read -r width height own visible ico_busy ico_wait ico_idle ico_jobs mode band accent <<<"${data%%$'\n'*}"
		# On dark, mauve text alone is too quiet for the selected workspace, so its
		# row is drawn in the theme's blue on a surface band, with a blue bar in
		# the left column. Light keeps plain mauve.
		local sel_bg="" sel_bar=" " sel_fg=$'\033[35m'
		if [ "$mode" = dark ] && [[ $band == \#?????? && $accent == \#?????? ]]; then
			sel_bg=$(printf '\033[48;2;%d;%d;%dm' "0x${band:1:2}" "0x${band:3:2}" "0x${band:5:2}")
			sel_fg=$(printf '\033[38;2;%d;%d;%dm' "0x${accent:1:2}" "0x${accent:3:2}" "0x${accent:5:2}")
			sel_bar="$sel_fg▌"$'\033[39m'
		fi

		if [ "$visible" = 1 ]; then
			# Back to its width whenever it is off it: tmux scales every pane
			# when the window resizes, and a window made in a detached session
			# is 80 wide until a client attaches to it.
			if [ "$width" != "$(width)" ]; then
				tmux resize-pane -t "$pane" -x "$(width)"
				continue
			fi
			local out="" map="" y=1 n=0 kind id name branch state title glyph colour line pad
			# Row 0 stays blank, level with the pane borders' title row.
			out+=$'\033[K\n'
			while IFS=$'\t' read -r kind id name branch; do
				case "$kind" in
				S)
					n=$((n + 1))
					name=${name:0:$((width - 7))}
					# The workspace this sidebar is in, in the active window
					# chip's mauve (blue on a band on dark); the rest plain. No full
					# reset inside the line, so the band runs to the right edge
					# through the trailing erase.
					if [ "$id" = "$own" ]; then
						line=$(printf '%s%s\033[2m%d\033[22m \033[1m%s%s\033[22;39m' "$sel_bg" "$sel_bar" "$n" "$sel_fg" "$name")
					else
						line=$(printf ' \033[2m%d\033[22m %s' "$n" "$name")
					fi
					# The close button, a column in from the right edge; 'x'
					# entries in the map are the clicks that land on it.
					pad=$((width - 2 - (3 + ${#n} + ${#name})))
					line+=$(printf '%*s\033[2m×\033[22m' "$((pad > 0 ? pad : 0))" '')
					out+="$line"$'\033[K\033[0m\n'
					map+=" $y=$id x$y=$id"
					y=$((y + 1))
					if [ -n "$branch" ]; then
						out+=$(printf '   \033[2m%s\033[0m' "${branch# }")$'\033[K\n'
						map+=" $y=$id"
						y=$((y + 1))
					fi
					;;
				A)
					# For agent lines the fields are pane, state and title.
					state=$name title=$branch
					case "$state" in
					busy) glyph=$ico_busy colour=33 ;;
					wait) glyph=$ico_wait colour=31 ;;
					jobs) glyph=$ico_jobs colour=34 ;;
					*) glyph=$ico_idle colour=32 ;;
					esac
					# Claude puts its own state glyph in front of the title.
					title=$(sed -E 's/^[^[:alnum:]]+ //' <<<"$title")
					out+=$(printf '   \033[%dm%s\033[0m %s' "$colour" "$glyph" "${title:0:$((width - 6))}")$'\033[K\n'
					map+=" $y=$id"
					y=$((y + 1))
					;;
				esac
			done <<<"${data#*$'\n'}"
			# Room permitting, a way in for the mouse to the project picker.
			if [ $((y + 2)) -le "$height" ]; then
				out+=$'\033[K\n'
				out+=$'\033[2m + new workspace\033[0m\033[K\n'
				map+=" $((y + 1))=new"
			fi
			if [ "$out" != "$last" ]; then
				printf '\033[H%s\033[J' "$out"
				tmux set-option -p -t "$pane" @sidebar_map "$map"
				last=$out
			fi
			timeout 5 tmux wait-for sidebar 2>/dev/null
		else
			# Off screen: nothing to keep fresh until something signals.
			tmux wait-for sidebar 2>/dev/null || exit 0
		fi
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
