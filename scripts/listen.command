#!/usr/bin/env bash
# Keeps the sessions folder current: asks the server which tmux sessions it
# keeps running, writes one runnable file per tmux session, and asks again
# on a clock until this process is stopped. Open this in a terminal and leave
# it running; open a session's file to attach.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$root/helpers/config.sh"

load_config
export SERVER TMUX_SESSIONS="${TMUX_SESSIONS:-}"

# Names the window after the server, so a terminal's tab says what it is
# watching instead of which process it is running.
printf '\033]0;%s\007' "tmux sessions on $SERVER"

# The header's lines, label and value, with every label padded to the
# longest so the values stand in one column.
header() {
  local labels=("tmux sessions on" "refreshed at" "refresh rate")
  local values=("$SERVER" "$(date '+%H:%M:%S')" "${REFRESH_SECONDS}s")
  local width=0 i
  for i in "${labels[@]}"; do [ ${#i} -gt $width ] && width=${#i}; done
  for i in "${!labels[@]}"; do printf '%-*s  %s\n' "$((width + 1))" "${labels[$i]}:" "${values[$i]}"; done
}

while true; do
  wipe
  header
  echo
  bash "$root/helpers/refresh.sh" || true
  sleep "$REFRESH_SECONDS"
done
