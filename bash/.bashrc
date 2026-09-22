#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

# Untracked secrets (API keys etc.) as KEY=value lines, exported. Keep it 0600.
if [[ -f ~/.config/secrets.env ]]; then
    set -a
    . ~/.config/secrets.env
    set +a
fi

alias vim='nvim'
export MANPAGER='nvim +Man!'

# eza (modern ls); --icons needs the Nerd Font kitty uses
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza --icons=auto --group-directories-first --long --git'
alias la='eza --icons=auto --group-directories-first --long --all --git'
alias lt='eza --icons=auto --tree --level=2'

# td: attach to the tmux session named after the current directory, creating it
# on first use. tmux can't address names containing . or :, so those become _.
td() {
    local session="${PWD##*/}"
    [[ $PWD == "$HOME" ]] && session=default
    session="${session//[.:]/_}"
    tmux has-session -t "=$session" 2>/dev/null ||
        tmux new-session -d -s "$session" -c "$PWD"
    if [[ -n $TMUX ]]; then
        tmux switch-client -t "=$session"
    else
        exec tmux attach -t "=$session"
    fi
}

# mise: puts the tool versions for the current directory on PATH at each prompt
command -v mise >/dev/null && eval "$(mise activate bash)"

command -v direnv >/dev/null && eval "$(direnv hook bash)"

# zoxide last: its prompt hook must see the final PATH. Defines z and zi.
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
alias zz='z'
