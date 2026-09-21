#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# gcr-ssh-agent (enabled by install.sh); an agent forwarded over SSH wins
export SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/gcr/ssh}

# Auto-start Hyprland on tty1 (not over SSH or on other TTYs)
if [[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec start-hyprland
fi
