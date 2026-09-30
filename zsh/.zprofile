#
# ~/.zprofile (login shells; runs before .zshrc)
#

# mise shims for everything that isn't an interactive shell, including Hyprland
# and the apps it launches (IDEs find java/go/node here); .zshrc's mise activate
# takes over in terminals.
export PATH="$HOME/.local/share/mise/shims:$PATH"

# gcr-ssh-agent (enabled by install.sh); an agent forwarded over SSH wins
export SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/gcr/ssh}

# Rootless Docker (install.sh): the user daemon's socket, for the docker CLI and for
# Testcontainers, whose cleanup container mounts the socket too
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=$XDG_RUNTIME_DIR/docker.sock

# Auto-start Hyprland from a login on tty1 (not over SSH or on other TTYs), for when
# greetd is off. greetd's session (hyprland-session) runs this file non-interactively
# and starts Hyprland itself.
if [[ -o interactive && -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec start-hyprland
fi
