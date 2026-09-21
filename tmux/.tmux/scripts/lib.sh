#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # every constant here is used by the modules that source it.
# Shared helpers for the tmux status modules.
#
# tmux runs each #(command) as a job and parses #[...] style sequences out of
# its output, but it does not re-expand #{...} there. So a module receives its
# colors as arguments (tmux expands #{@thm_*} before exec) and prints its own
# styling. A module that has nothing to say prints nothing, and its pill
# disappears from the bar entirely.
#
# Every glyph below is written as a \u escape rather than pasted in literally.
# They are private-use codepoints: they carry no meaning outside a patched font,
# they are invisible in most diffs and editors, and tooling that touches this
# file can silently drop them, which leaves the bar rendering blank gaps. The
# escape says exactly which glyph is meant and cannot be mangled. Every
# codepoint here is present in JetBrainsMono Nerd Font.

# Rounded pill caps (Powerline).
readonly CAP_L=$'\ue0b6'          # powerline left half circle
readonly CAP_R=$'\ue0b4'          # powerline right half circle

# Material Design icons, all above U+FFFF.
readonly ICO_BRANCH=$'\U000f062c'   # md-source-branch
readonly ICO_CONFLICT=$'\U000f0028' # md-alert-circle
readonly ICO_CPU=$'\U000f0ee0'      # md-cpu_64_bit
readonly ICO_DOCKER=$'\U000f0868'   # md-docker
readonly ICO_MEM=$'\U000f035b'      # md-memory
readonly ICO_WIFI=$'\U000f05a9'     # md-wifi
readonly ICO_WIFI_OFF=$'\U000f05aa' # md-wifi-off

# Escape text that tmux will parse as a format: '#' is the escape character,
# so a branch named 'feat/#12' has to arrive as 'feat/##12'.
esc() {
	printf '%s' "${1//#/##}"
}

# pill <surface> <accent> <icon> [label]
# Rounded pill: caps drawn in the surface color over the terminal background,
# icon in the accent, label in PILL_TEXT (or the accent when PILL_TEXT is empty).
#
# The icon and label are separate arguments because the two flavors colour them
# differently. On dark both take the accent — bright pastel on #363a4f, 5-8:1.
# On light the accent cannot carry text at any readable ratio, so the label goes
# neutral and only the icon stays accented. palette.sh decides which, and
# status.sh exports it; see palette.sh for why.
#
# Spacing is the caller's job. This draws CAP_L, the icon flush against it, the
# label verbatim, then CAP_R flush against the label — no spaces of its own. The
# MD glyphs (cpu, memory, battery, branch, wifi) carry their own left-side
# bearing, so an injected leading space made them float away from the cap; and
# with spacing here every pill was forced to the same left/right padding. Now
# each module decides: the numeric pills right-align their value with '%3d%%'
# (see battery.sh), so it sits one column off the icon and tight against the right
# cap; the text pills (git, offline) pad their own label so words don't touch
# the caps.
#
# Pass label empty for an icon-only pill.
pill() {
	local surface="$1" accent="$2" icon="$3" label="${4:-}"
	local text_fg="${PILL_TEXT:-$accent}"
	printf '#[fg=%s,bg=default]%s#[bg=%s,bold]#[fg=%s]%s' \
		"$surface" "$CAP_L" "$surface" "$accent" "$icon"
	[ -n "$label" ] && printf '#[fg=%s]%s' "$text_fg" "$label"
	printf '#[fg=%s,bg=default,nobold]%s' "$surface" "$CAP_R"
}
