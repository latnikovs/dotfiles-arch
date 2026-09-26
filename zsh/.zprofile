#
# ~/.zprofile (login shells; runs before .zshrc)
#

# mise shims for everything that isn't an interactive shell, including Hyprland
# and the apps it launches (IDEs find java/go/node here); .zshrc's mise activate
# takes over in terminals.
export PATH="$HOME/.local/share/mise/shims:$PATH"

# gcr-ssh-agent (enabled by install.sh); an agent forwarded over SSH wins
export SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/gcr/ssh}

# Auto-start Hyprland on tty1 (not over SSH or on other TTYs)
if [[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec start-hyprland
fi
