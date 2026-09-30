#
# ~/.zshrc (interactive shells)
#

typeset -U path
export PATH="$HOME/.local/bin:$PATH"

# Untracked secrets (API keys etc.) as KEY=value lines, exported. Keep it 0600.
if [[ -f ~/.config/secrets.env ]]; then
    set -a
    . ~/.config/secrets.env
    set +a
fi

PROMPT='[%n@%m %1~]%# '

# History, shared live between terminals and tmux panes
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt share_history extended_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

setopt auto_cd interactive_comments

# Completion: a menu to move through, case-insensitive, coloured like ls.
# zsh-completions adds its functions to site-functions, which fpath already has.
zmodload zsh/complist
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
bindkey -M menuselect h vi-backward-char j vi-down-line-or-history \
    k vi-up-line-or-history l vi-forward-char

# Vi mode: Esc switches without the default 0.4s wait, backspace and ^W/^U work
# past where insert mode started, and the cursor is a bar in insert, a block in normal
bindkey -v
KEYTIMEOUT=1
bindkey -M viins '^?' backward-delete-char '^H' backward-delete-char \
    '^W' backward-kill-word '^U' backward-kill-line
zle-keymap-select() {
    [[ $KEYMAP == vicmd ]] && print -n '\e[2 q' || print -n '\e[6 q'
}
zle-line-init() { print -n '\e[6 q'; }
zle -N zle-keymap-select
zle -N zle-line-init
# v in normal mode edits the command line in nvim
autoload -Uz edit-command-line && zle -N edit-command-line
bindkey -M vicmd v edit-command-line

alias vim='nvim'
export MANPAGER='nvim +Man!'
alias grep='grep --color=auto'
alias remind='~/.config/hypr/scripts/remind'   # remind 20m tea, remind tomorrow 9:00 dentist

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

# ssh sends the locale, as macOS' ssh does (its sshd accepts LANG and LC_*): without
# it the shell there runs in the C locale and miscounts the prompt's Unicode
# characters. From kitty or tmux it goes as xterm-256color, since remote hosts
# (macOS among them) often lack their terminfo. Either way the prompt draws as garbage.
ssh() {
    local term=$TERM
    [[ $term == (xterm-kitty|tmux-256color) ]] && term=xterm-256color
    TERM=$term command ssh -o SendEnv=LANG -o 'SendEnv=LC_*' "$@"
}

# mise: puts the tool versions for the current directory on PATH at each prompt
(( $+commands[mise] )) && eval "$(mise activate zsh)"

(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

# fzf: ^R history search, ^T file picker, Alt-C cd into a subdirectory. After
# bindkey -v, which would reset its bindings.
(( $+commands[fzf] )) && source <(fzf --zsh)

(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
alias zz='z'

# Fish-style suggestions from history, taken with →
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
# Syntax highlighting last, so it wraps every widget defined above
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
