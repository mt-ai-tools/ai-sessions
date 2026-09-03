#!/usr/bin/env bash
# Keeps the sessions folder current: asks the server which tmux sessions it
# keeps running, writes one runnable file per tmux session, and asks again
# on a clock until this window is closed. Open this in a terminal and leave
# it open; open a session's file to attach.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$root/helpers/config.sh"

load_config
export SERVER TMUX_SESSIONS="${TMUX_SESSIONS:-}"

while true; do
  clear
  echo "tmux sessions on $SERVER — $(date '+%H:%M:%S'), again in ${REFRESH_SECONDS}s, close this window to stop"
  echo
  bash "$root/helpers/refresh.sh" || true
  sleep "$REFRESH_SECONDS"
done
