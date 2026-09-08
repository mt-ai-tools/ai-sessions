#!/usr/bin/env bash
# One refresh: asks the server which tmux sessions it keeps running and
# rewrites the sessions folder to match, one runnable file per tmux
# session. The watch script runs this on a clock; the config is already
# loaded by whoever runs it. A server that cannot be reached leaves the
# folder as it was, and when the config names the server in Tailscale,
# what Tailscale knows about it is said under ssh's own error.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$root/helpers/remote.sh"
. "$root/helpers/listing.sh"
. "$root/helpers/sessions-dir.sh"
. "$root/helpers/tailscale.sh"

status=0
raw="$(remote_run "$(list_panes_command)" | filter_listing "${TMUX_SESSIONS:-}")" || status=$?
if [ "$status" -eq "$SSH_LINK_LOST" ]; then
  reason="$(tailscale_reason)" && echo "ai-sessions: $reason"
fi
[ "$status" -eq 0 ] || exit "$status"

clear_session_files
if [ -z "$raw" ]; then
  echo "no tmux sessions running on $SERVER${TMUX_SESSIONS:+ named $TMUX_SESSIONS}"
  exit 0
fi

printf '%s\n' "$raw" | format_listing
while IFS= read -r name; do
  [ -n "$name" ] || continue
  write_session_file "$name"
done < <(printf '%s\n' "$raw" | listing_names)
