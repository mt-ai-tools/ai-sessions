#!/usr/bin/env bash
# What to do when the link to the server is lost: say so, say why as far
# as Tailscale can tell, wait, and let the caller reach again. Shared by
# everything that keeps a link open — a session window, a forwarded port —
# so a lost link reads and behaves the same in each. Sourced, never
# executed; expects the config loaded and remote.sh sourced.
#
# The link to the server does not outlive a closed lid: the laptop sleeps,
# the server stops hearing from it, and ssh ends. Reaching again as soon
# as the lid opens is what puts the window back where it was. Away from
# the server's own network the link is lost for other reasons — Tailscale
# off on this machine, the server down, its key run out — and these do not
# mend in three seconds. So the wait grows while the link stays lost, and
# when the config names the server in Tailscale, what Tailscale knows
# about it is said with each wait.
. "$(dirname "${BASH_SOURCE[0]}")/tailscale.sh"

# The first wait after the link is lost, in seconds. Short, since the wait
# is what stands between an opened lid and the window's work; and the
# reach itself gives up quickly when nothing answers.
RECONNECT_SECONDS=3

# The wait doubles each time the link is lost again, up to this: a network
# down for an hour is not helped by a reach every three seconds.
RECONNECT_MAX_SECONDS=30

# A link that held this long before it was lost counts as a fresh loss, and
# the wait starts short again: the long wait was for a link that never came
# back, not for one that worked for an hour.
RECONNECT_RESET_SECONDS=30

# The next wait, in seconds. Kept here between losses.
reconnect_wait_seconds=$RECONNECT_SECONDS

# Says the loss and waits. Takes how many seconds the link held before it
# was lost, and what goes on meanwhile as a phrase ("session notes goes on
# there"), which the message carries so the window says what it is
# waiting for.
reconnect_wait() {
  local held="$1" what="$2" reason
  [ "$held" -lt "$RECONNECT_RESET_SECONDS" ] || reconnect_wait_seconds=$RECONNECT_SECONDS
  echo
  echo "ai-sessions: link to $SERVER lost, $what — reconnecting in ${reconnect_wait_seconds}s, ctrl-c to stop"
  reason="$(tailscale_reason)" && echo "ai-sessions: $reason"
  sleep "$reconnect_wait_seconds"
  reconnect_wait_seconds=$((reconnect_wait_seconds * 2))
  [ "$reconnect_wait_seconds" -le "$RECONNECT_MAX_SECONDS" ] || reconnect_wait_seconds=$RECONNECT_MAX_SECONDS
}
