#!/usr/bin/env bash
# Puts this terminal into one session on the server, and keeps it there.
# Every session file runs this with its own name; nothing else attaches.
#
# The link to the server does not outlive a closed lid: the laptop sleeps,
# the server stops hearing from it, and ssh ends. The session on the
# server does not notice. So when ssh ends that way, this waits and
# attaches again, as often as it takes, and the window is back in its
# session moments after the lid opens. Detaching on purpose, or the
# session being gone from the server, ends it as before.
#
# Away from the server's own network the link is lost for other reasons —
# Tailscale off on this machine, the server down, its key run out — and
# these do not mend in three seconds. So the wait grows while the link
# stays lost, and when the config names the server in Tailscale, what
# Tailscale knows about it is said with each wait.
#
# Usage: <name>
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/config.sh"
. "$here/remote.sh"
. "$here/title.sh"
. "$here/tailscale.sh"

# The first wait after the link is lost, in seconds. Short, since the wait
# is what stands between an opened lid and the session; and the reach
# itself gives up quickly when nothing answers.
RECONNECT_SECONDS=3

# The wait doubles each time the link is lost again, up to this: a network
# down for an hour is not helped by a reach every three seconds.
RECONNECT_MAX_SECONDS=30

# A link that held this long before it was lost counts as a fresh loss, and
# the wait starts short again: the long wait was for a link that never came
# back, not for one that worked for an hour.
RECONNECT_RESET_SECONDS=30

name="${1:?attach.sh <name>}"
load_config
wait_seconds=$RECONNECT_SECONDS
while true; do
  status=0
  SECONDS=0
  remote_terminal "tmux attach -t $(printf %q "$name") $TMUX_TITLE_COMMANDS" || status=$?
  [ "$status" -eq "$SSH_LINK_LOST" ] || exit "$status"
  [ "$SECONDS" -lt "$RECONNECT_RESET_SECONDS" ] || wait_seconds=$RECONNECT_SECONDS
  echo
  echo "ai-sessions: link to $SERVER lost, session $name goes on there — reconnecting in ${wait_seconds}s, ctrl-c to stop"
  reason="$(tailscale_reason)" && echo "ai-sessions: $reason"
  sleep "$wait_seconds"
  wait_seconds=$((wait_seconds * 2))
  [ "$wait_seconds" -le "$RECONNECT_MAX_SECONDS" ] || wait_seconds=$RECONNECT_MAX_SECONDS
done
