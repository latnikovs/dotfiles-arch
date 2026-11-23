#
# Per-directory history, sourced from ~/.zshrc after fzf and bindkey -v
#

# Each command is also logged with its directory as
# "dir<TAB>command<NUL>" (NUL so multi-line commands survive). Alt-R searches
# the commands run in this directory or below it, newest first; ^R stays global.
# Each shell start trims the file in the background to the newest DIRHIST_MAX
# distinct commands per directory. Appends and the trim share a lock, so a
# command run in another shell during a trim isn't lost.
DIRHIST_FILE=${XDG_STATE_HOME:-~/.local/state}/zsh/dirhist
DIRHIST_MAX=300
[[ -d ${DIRHIST_FILE:h} ]] || mkdir -p ${DIRHIST_FILE:h}
# zsystem flock won't create the file it locks
[[ -e $DIRHIST_FILE.lock ]] || : >>| $DIRHIST_FILE.lock
zmodload -F zsh/system b:zsystem

_dirhist_add() {
    local cmd=${1%$'\n'} fd
    # Same rule as hist_ignore_space; return 0 so zsh still saves the line.
    [[ -n $cmd && $cmd != ' '* ]] || return 0
    zsystem flock -t 1 -i 0.05 -f fd $DIRHIST_FILE.lock 2>/dev/null
    print -rn -- "$PWD"$'\t'"$cmd"$'\0' >>| $DIRHIST_FILE
    [[ -n $fd ]] && zsystem flock -u $fd
    return 0
}
autoload -Uz add-zsh-hook
add-zsh-hook zshaddhistory _dirhist_add

_dirhist_trim() {
    [[ -s $DIRHIST_FILE ]] || return 0
    local rec dir fd
    local -a keep
    local -A seen count
    zsystem flock -t 5 -f fd $DIRHIST_FILE.lock 2>/dev/null || return 0
    for rec in ${(Oa)${(0)"$(<$DIRHIST_FILE)"}}; do
        dir=${rec%%$'\t'*}
        (( $+seen[$rec] || ${count[$dir]:-0} >= DIRHIST_MAX )) && continue
        seen[$rec]=1
        count[$dir]=$(( ${count[$dir]:-0} + 1 ))
        keep+=$rec
    done
    print -rN -- ${(Oa)keep} >| $DIRHIST_FILE.tmp && mv -f $DIRHIST_FILE.tmp $DIRHIST_FILE
    zsystem flock -u $fd
}
_dirhist_trim &!

dirhist-widget() {
    [[ -r $DIRHIST_FILE ]] || return 0
    local rec dir cmd selected
    local -a hits
    local -A seen
    for rec in ${(Oa)${(0)"$(<$DIRHIST_FILE)"}}; do
        dir=${rec%%$'\t'*} cmd=${rec#*$'\t'}
        [[ $dir == "$PWD" || $dir == "$PWD"/* ]] || continue
        (( $+seen[$cmd] )) && continue
        seen[$cmd]=1
        hits+=$cmd
    done
    selected=$(print -rN -- $hits | fzf --read0 --scheme=history --height=40% \
        --layout=reverse --prompt="${PWD/#$HOME/~} > " --query="$LBUFFER")
    if [[ -n $selected ]]; then
        BUFFER=$selected
        CURSOR=$#BUFFER
    fi
    zle reset-prompt
}
zle -N dirhist-widget
bindkey -M viins '\er' dirhist-widget
bindkey -M vicmd '\er' dirhist-widget
