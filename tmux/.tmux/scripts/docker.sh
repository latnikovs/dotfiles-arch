#!/usr/bin/env bash
# tmux status module: the container engine, and how much is running on it.
# Usage: docker.sh <surface> <accent> <starting-accent>
#
# Prints nothing at all when there is no engine up, which is the point: a docker
# pill that is always there tells you nothing, and a machine with the VM stopped
# is the normal state on a laptop. The pill appearing IS the signal.
#
# Three states, in the order they are cheapest to rule out:
#
#   no socket           nothing. Costs a stat(2); the common case pays nothing.
#   socket, no answer   'starting', but only if a lima/colima process is
#                       actually up -- colima leaves its socket file behind on
#                       an unclean stop, so a stale socket alone must not
#                       announce a VM that is not coming.
#   socket, answers     the engine, with its running container count.
#
# The count comes from the Docker API over the unix socket rather than from
# `docker ps`, for two reasons. The CLI costs ~65ms of Go startup against
# curl's ~12ms, and this runs inside status.sh's single job every interval. More
# importantly curl takes --max-time: a half-booted or wedged VM answers its
# socket and then hangs, and `docker ps` has no timeout flag to stop that from
# freezing the whole right-hand side of the bar.
set -u

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

surface="${1:-#363a4f}"
accent="${2:-#8aadf4}"
starting="${3:-#f5a97f}"

# DOCKER_HOST wins when it is a unix socket, so a non-default context (colima's
# own, a second VM) is honoured. A tcp:// host is left alone: it is someone
# else's machine, and this pill is about this one.
candidates=()
case "${DOCKER_HOST:-}" in
	unix://*) candidates+=("${DOCKER_HOST#unix://}") ;;
esac
candidates+=("$HOME/.colima/default/docker.sock" "$HOME/.docker/run/docker.sock" /var/run/docker.sock)

sock=""
for candidate in "${candidates[@]}"; do
	if [ -S "$candidate" ]; then
		sock="$candidate"
		break
	fi
done
[ -n "$sock" ] || exit 0

# /containers/json lists running containers only. limit=0 is not a thing here,
# so the whole list comes back and the ids are counted -- there are never enough
# containers on a laptop for that to matter.
if json="$(curl -s --max-time 1 --unix-socket "$sock" http://localhost/v1.41/containers/json 2>/dev/null)"; then
	count="$(printf '%s' "$json" | grep -o '"Id"' | wc -l | tr -d ' ')"
	pill "$surface" "$accent" "$ICO_DOCKER" " $count"
	exit 0
fi

# Socket present, daemon silent. Only claim it is coming up if something is
# actually booting it.
if pgrep -f 'limactl hostagent|colima' >/dev/null 2>&1; then
	pill "$surface" "$starting" "$ICO_DOCKER" " ..."
fi
