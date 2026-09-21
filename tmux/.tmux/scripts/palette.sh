#!/usr/bin/env bash
# Publishes the bar's pill colors as tmux options, derived per flavor.
#
# Why the two flavors cannot share one rule:
#
# The bar's dark look is accent-coloured text on a dark surface pill. That works
# because Macchiato's accents are bright pastels against #363a4f — every pill
# lands at 5-8:1. Latte inverts both halves: its accents are mid-dark and
# saturated, its surface_0 is light grey, and the pairing collapses to 1.7-3.5:1.
# Six of the seven pills fail WCAG's 3:1 floor; the yellow one, at 1.7:1, is
# barely there. It is not a tuning problem — Latte's yellow (#df8e1d) and peach
# (#fe640b) sit at mid luminance and contrast against neither light nor dark, so
# no arrangement of 'accent as text' survives.
#
# So on Latte the colour stops carrying the text and becomes a cue instead: the
# pill keeps its quiet surface, the label goes neutral (@thm_fg, 5.2:1 — the one
# pairing that already passed), and only the icon is accented. An icon is a
# graphic, not text, so it answers to WCAG's 3:1 floor rather than 4.5:1, and at
# 3:1 the accents barely have to move — they keep their hue instead of collapsing
# into brown. Filling each pill with its accent was the other way to make the
# numbers pass, but seven saturated chips in a row is a lot of bar.
#
# The two pills that are emphasis rather than information — the session and the
# active window — keep a colour of their own so they still read as identity
# against a row of grey info pills. On dark that is the accent, filled. On light
# a filled accent shouts next to the quiet pills, so it becomes a badge instead:
# a pale wash of the accent carrying dark accent text.
#
# All of it is measured, not tabulated: the ratios come out of the same WCAG
# formula terminal/kitty/generate-themes.py uses, so a Catppuccin palette change
# re-derives instead of silently going stale.
#
# Published options. Each is already the right colour for the current flavor, so
# nothing downstream branches on it:
#   @badge_<name>     fill for an emphasis pill (session, active window): the
#   @badge_fg_<name>  accent itself on dark, a pale wash of it on light — with
#                     crust and dark accent text respectively.
#   @fill_<name>  the surface a normal pill is drawn on.
#   @icon_<name>  colour for that pill's icon: the raw accent on dark, minimally
#                 darkened to 3:1 on light.
#   @badge_icon_<name>  the same, but for an icon drawn *on the mauve badge*
#                 rather than on a pill: the active window chip. On Macchiato
#                 that fill is light mauve and the accents are light pastels, so
#                 the raw accent lands near 1.5:1 there and the icon all but
#                 vanishes -- the one place the dark look's "accent on surface"
#                 rule does not hold, because the surface is not the surface.
#   @text_<name>  colour for that pill's label: the accent on dark (that IS the
#                 dark look), neutral @thm_fg on light.
#   @pill_text    what pill() should colour a label with, or empty to mean 'use
#                 the accent' — see lib.sh.
#
# Must run after tpm, since it reads the @thm_* the catppuccin plugin sets.
set -u

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACCENTS=(green sapphire mauve peach teal yellow red lavender blue sky)

flavor="$("$dir/flavor.sh")"
# The plugin names these @thm_bg / @thm_fg, not the @thm_base / @thm_text the
# Catppuccin palette docs use.
base="$(tmux show -gqv @thm_bg 2>/dev/null)"
crust="$(tmux show -gqv @thm_crust 2>/dev/null)"

# Nothing to derive from if the palette has not loaded yet.
[ -n "$base" ] || exit 0

fg="$(tmux show -gqv @thm_fg 2>/dev/null)"

if [ "$flavor" = latte ]; then
	# Labels go neutral; only icons stay accented.
	tmux set -g @pill_text "$fg"
else
	# Empty: the label keeps taking the accent, which is the dark look.
	tmux set -g @pill_text ""
fi

# How much accent a light badge's wash carries. Low enough to stay a wash rather
# than a chip; the text on it is re-derived either way, so this is taste, not
# contrast.
BADGE_TINT=0.18

# hex_rgb <#rrggbb> — prints 'r g b' as decimals. The hex parsing is done here
# rather than in awk because awk's strtonum() is a gawk extension and macOS
# ships BSD awk, where it does not exist.
hex_rgb() {
	local h="${1#\#}"
	printf '%d %d %d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

# blend <fg> <bg> <alpha> — <alpha> of <fg> laid over <bg>.
blend() {
	local xr xg xb yr yg yb
	read -r xr xg xb <<<"$(hex_rgb "$1")"
	read -r yr yg yb <<<"$(hex_rgb "$2")"
	awk -v xr="$xr" -v xg="$xg" -v xb="$xb" \
		-v yr="$yr" -v yg="$yg" -v yb="$yb" -v a="$3" '
		BEGIN {
			printf "#%02x%02x%02x", \
				int(xr * a + yr * (1 - a)), \
				int(xg * a + yg * (1 - a)), \
				int(xb * a + yb * (1 - a))
		}'
}

# darken_to <hex> <against> <target> — scale the colour down until it reaches
# <target>:1 against <against>. Prints the input unchanged when it already
# passes, and gives up at 20% rather than spiral to black if a palette ever
# makes the target unreachable.
#
# The target is the caller's because the two uses have different floors: 4.5:1
# for a colour that carries text, 3:1 for one that only has to be seen (an icon
# is a graphic under WCAG, not text).
darken_to() {
	local cr cg cb br bgr bb
	read -r cr cg cb <<<"$(hex_rgb "$1")"
	read -r br bgr bb <<<"$(hex_rgb "$2")"
	awk -v cr="$cr" -v cg="$cg" -v cb="$cb" -v target="$3" \
		-v br="$br" -v bgr="$bgr" -v bb="$bb" '
		function chan(v) {
			v = v / 255
			return (v <= 0.04045) ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4
		}
		function lum(r, g, b) {
			return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)
		}
		function ratio(la, lb,   hi, lo) {
			hi = (la > lb) ? la : lb; lo = (la > lb) ? lb : la
			return (hi + 0.05) / (lo + 0.05)
		}
		BEGIN {
			lbg = lum(br, bgr, bb)
			for (f = 1.0; f >= 0.2; f -= 0.01) {
				r = int(cr * f); g = int(cg * f); b = int(cb * f)
				if (ratio(lum(r, g, b), lbg) >= target) {
					printf "#%02x%02x%02x", r, g, b
					exit
				}
			}
			printf "#%02x%02x%02x", cr, cg, cb
		}'
}

surface="$(tmux show -gqv @thm_surface_0 2>/dev/null)"

# The active window chip is always the mauve badge, so icons drawn on it are
# measured against that one colour. Derived before the loop because the loop
# reaches mauve partway through, after green has already needed this value.
mauve="$(tmux show -gqv @thm_mauve 2>/dev/null)"
if [ "$flavor" = latte ]; then
	badge_mauve="$(blend "$mauve" "$base" "$BADGE_TINT")"
else
	badge_mauve="$mauve"
fi

for name in "${ACCENTS[@]}"; do
	value="$(tmux show -gqv "@thm_$name" 2>/dev/null)"
	[ -n "$value" ] || continue

	tmux set -g "@fill_$name" "$surface"

	# 3:1, the graphic floor, same as @icon_*: this is a glyph, not text.
	tmux set -g "@badge_icon_$name" "$(darken_to "$value" "$badge_mauve" 3.0)"

	if [ "$flavor" = latte ]; then
		# Icon only has to clear 3:1 against the pill, so it barely moves and
		# keeps its hue. The label is neutral and already at 5.2:1.
		tmux set -g "@icon_$name" "$(darken_to "$value" "$surface" 3.0)"
		tmux set -g "@text_$name" "$fg"

		# Badge: a wash of the accent, with the accent itself darkened until it
		# reads on that wash.
		wash="$(blend "$value" "$base" "$BADGE_TINT")"
		tmux set -g "@badge_$name" "$wash"
		tmux set -g "@badge_fg_$name" "$(darken_to "$value" "$wash" 4.5)"
	else
		tmux set -g "@icon_$name" "$value"
		tmux set -g "@text_$name" "$value"
		tmux set -g "@badge_$name" "$value"
		tmux set -g "@badge_fg_$name" "$crust"
	fi
done
