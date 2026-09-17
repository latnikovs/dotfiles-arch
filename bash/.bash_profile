#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Auto-start Hyprland on tty1 (not over SSH or on other TTYs)
if [[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec start-hyprland
fi
