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

# Wipes the screen and its scrollback, then homes the cursor, so each round
# replaces the last instead of piling under it. Spelled out rather than left
# to the clear command, whose output differs between terminals.
wipe() { printf '\033[2J\033[3J\033[H'; }

while true; do
  wipe
  printf '%-40s %s\n' "$SERVER" "$(date '+%H:%M:%S')"
  echo "every ${REFRESH_SECONDS}s; close this window to stop"
  echo
  bash "$root/helpers/refresh.sh" || true
  sleep "$REFRESH_SECONDS"
done
