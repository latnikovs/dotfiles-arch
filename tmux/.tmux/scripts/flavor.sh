#!/usr/bin/env bash
# Prints the current appearance, light or dark.
#
# This is the tmux side of the same light/dark rule kitty follows via
# light-theme.auto.conf / dark-theme.auto.conf, so the status bar cannot end up
# light on a dark terminal. On Linux that is the freedesktop color-scheme
# setting (scripts/theme, driven by darkman); on macOS the system appearance.
#
# Override with TMUX_FLAVOR=light|dark to pin it.
set -u

if [ -n "${TMUX_FLAVOR:-}" ]; then
	printf '%s' "$TMUX_FLAVOR"
	exit 0
fi

if [ "$(uname -s)" = Darwin ]; then
	# AppleInterfaceStyle only exists while the appearance is Dark; in Light mode
	# the key is absent and `defaults read` fails.
	[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = Dark ] && printf 'dark' || printf 'light'
elif [ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" = "'prefer-light'" ]; then
	printf 'light'
else
	printf 'dark'
fi
