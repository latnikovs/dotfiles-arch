#!/usr/bin/env bash
# Prints the Catppuccin flavor matching the current OS appearance.
#
# This is the tmux side of the same light/dark rule kitty follows via
# light-theme.auto.conf / dark-theme.auto.conf, so the status bar cannot end up
# light on a dark terminal.
#
# Override with TMUX_FLAVOR=latte|macchiato to pin it.
set -u

if [ -n "${TMUX_FLAVOR:-}" ]; then
	printf '%s' "$TMUX_FLAVOR"
	exit 0
fi

# AppleInterfaceStyle only exists while the appearance is Dark; in Light mode
# the key is absent and `defaults read` fails.
if [ "$(uname -s)" = Darwin ] &&
	[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" != Dark ]; then
	printf 'latte'
else
	printf 'macchiato'
fi
