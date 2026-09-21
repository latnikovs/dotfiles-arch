#!/usr/bin/env bash
# tmux status module: current branch and working-tree state.
# Usage: git.sh <path> <surface> <clean-accent> <dirty-accent>
# Prints nothing when <path> is not inside a work tree.
set -u

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

path="${1:-$PWD}"
surface="${2:-#363a4f}"
clean="${3:-#a6da95}"
dirty="${4:-#f5a97f}"
# Ticket-style branches ('feature/PROJ-1234-some-description') would otherwise
# push the rest of the bar off the right edge.
maxlen="${5:-20}"

cd "$path" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# A fresh repo with no commits still has a symbolic HEAD; a detached HEAD does
# not, and falls back to the short sha.
branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" ||
	branch="$(git rev-parse --short HEAD 2>/dev/null)" ||
	exit 0

staged=0 modified=0 untracked=0 conflicted=0
# --no-optional-locks: a plain 'git status' refreshes the index and takes
# .git/index.lock to write it back. Running every status-interval, it would
# grab that lock mid-commit and make the commit fail.
while IFS= read -r line; do
	case "${line:0:2}" in
		'??') untracked=$((untracked + 1)); continue ;;
		# Both sides modified / added: a merge conflict, not ordinary work.
		'U'?|?'U'|'DD'|'AA') conflicted=$((conflicted + 1)); continue ;;
	esac
	[ "${line:0:1}" != ' ' ] && staged=$((staged + 1))
	[ "${line:1:1}" != ' ' ] && modified=$((modified + 1))
done < <(git --no-optional-locks status --porcelain 2>/dev/null)

ahead=0 behind=0
if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
	read -r behind ahead < <(
		git rev-list --left-right --count "$upstream...HEAD" 2>/dev/null
	) || { behind=0; ahead=0; }
fi

dirty_marks=''
[ "$conflicted" -gt 0 ] && dirty_marks+=" ${ICO_CONFLICT}${conflicted}"
[ "$staged" -gt 0 ] && dirty_marks+=" ✚${staged}"
[ "$modified" -gt 0 ] && dirty_marks+=" ●${modified}"
[ "$untracked" -gt 0 ] && dirty_marks+=" …${untracked}"

# Being ahead/behind the upstream is not the same as a dirty tree: it is worth
# showing, but it should not colour the pill.
sync_marks=''
[ "$ahead" -gt 0 ] && sync_marks+=" ⇡${ahead}"
[ "$behind" -gt 0 ] && sync_marks+=" ⇣${behind}"

accent="$clean"
[ -n "$dirty_marks" ] && accent="$dirty"

[ "${#branch}" -gt "$maxlen" ] && branch="${branch:0:maxlen-1}…"

# pill() adds no spacing of its own: one column off the icon, tight against the
# right cap — same as the numeric pills. dirty_marks/sync_marks lead with spaces.
pill "$surface" "$accent" "$ICO_BRANCH" " $(esc "$branch")${dirty_marks}${sync_marks}"
