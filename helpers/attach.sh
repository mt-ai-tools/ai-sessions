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
# Usage: <name>
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/config.sh"
. "$here/remote.sh"
. "$here/title.sh"

# How long to wait before reaching for the server again after the link is
# lost. Short, since the wait is what stands between an opened lid and
# the session; and the reach itself gives up quickly when nothing answers.
RECONNECT_SECONDS=3

name="${1:?attach.sh <name>}"
load_config
while true; do
  status=0
  remote_terminal "tmux attach -t $(printf %q "$name") $TMUX_TITLE_COMMANDS" || status=$?
  [ "$status" -eq "$SSH_LINK_LOST" ] || exit "$status"
  echo
  echo "ai-sessions: link to $SERVER lost, session $name goes on there — reconnecting every ${RECONNECT_SECONDS}s, ctrl-c to stop"
  sleep "$RECONNECT_SECONDS"
done
