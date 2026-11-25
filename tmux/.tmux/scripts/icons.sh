#!/usr/bin/env bash
# Publishes the glyphs tmux.conf needs as tmux options, so the config file can
# stay plain ASCII and refer to them as #{@ico_*} / #{@cap_*}.
#
# tmux config has no \u escape, so the alternative is pasting private-use
# codepoints straight into tmux.conf, where they are invisible to read and easy
# for tooling to silently drop. Sourcing lib.sh also keeps one definition of the
# pill caps shared between the config and the module scripts.
set -u

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

tmux set -g @cap_l "$CAP_L"
tmux set -g @cap_r "$CAP_R"

tmux set -g @ico_session $'\U000f018d'  # md-console
tmux set -g @ico_prefix $'\U000f030c'   # md-keyboard
tmux set -g @ico_zoom $'\U000f0293'     # md-fullscreen
tmux set -g @ico_clock $'\U000f0150'    # md-clock_outline
tmux set -g @ico_date $'\U000f00ed'     # md-calendar
tmux set -g @ico_branch $'\U000f062c'   # md-source-branch, as lib.sh's ICO_BRANCH

# Window icons, keyed off #{pane_current_command} by the @win_icon map.
# Not MDI: Material has no vim glyph, and the f085e this used to point at is
# md-clipboard_pulse_outline -- a clipboard, which is what every nvim window has
# been showing. The font's own glyph names say so; see the audit note in README.
tmux set -g @ico_nvim $'\ue6ae'         # custom-neovim
tmux set -g @ico_vim $'\ue62b'          # custom-vim
tmux set -g @ico_git $'\U000f02a2'      # md-git
tmux set -g @ico_go $'\U000f07d3'       # md-language-go
tmux set -g @ico_node $'\U000f0399'     # md-nodejs
tmux set -g @ico_python $'\U000f0320'   # md-language-python
tmux set -g @ico_docker $'\U000f0868'   # md-docker
tmux set -g @ico_ssh $'\U000f0318'      # md-lan-connect
tmux set -g @ico_java $'\U000f0176'     # md-coffee
tmux set -g @ico_shell $'\U000f018d'    # md-console
# Not a robot: md-robot is an android head, and the sparkle is what reads as
# "AI" now -- md-shimmer keeps that in the same Material family as the rest of
# the bar, and its filled mark survives the mauve badge better than an outline.
tmux set -g @ico_claude $'\U000f1545'   # md-shimmer
tmux set -g @ico_default $'\U000f0349'  # md-magnify

# Claude Code state, appended to a window tab by @claude_dot and listed in the
# sidebar. An agent is a star: it twinkles while it thinks (claude-spin.sh
# animates it through Claude Code's own spinner, ✢ ✳ ✶ ✻ ✽, so the bar moves
# the way the agent's own pane does), it rings a bell when it needs you, and it
# settles into a still ✦ when the turn is done. A dotted ring means it is done
# but a command it started is still running in the background.
# The glyphs here are the stills: what is drawn when nothing animates them.
# The stars come from the fallback font; JetBrains Mono has none of them.
tmux set -g @ico_claude_busy '✻'               # mid-turn (animated by claude-spin.sh)
tmux set -g @ico_claude_wait $'\U000f009e'      # md-bell_ring: it is asking you something (rings)
tmux set -g @ico_claude_idle '✦'               # turn finished
tmux set -g @ico_claude_jobs '◌'               # finished, a background command still running
