#!/usr/bin/env bash
# One refresh: asks the server which tmux sessions it keeps running and
# rewrites the sessions folder to match, one runnable file per tmux
# session. The listen script runs this on a clock; the config is already
# loaded by whoever runs it.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$root/helpers/remote.sh"
. "$root/helpers/listing.sh"
. "$root/helpers/sessions-dir.sh"

raw="$(remote_run "$(list_panes_command)" | filter_listing "${TMUX_SESSIONS:-}")"

clear_session_files
if [ -z "$raw" ]; then
  echo "no tmux sessions running on $SERVER${TMUX_SESSIONS:+ named $TMUX_SESSIONS}"
  exit 0
fi

listing_heading
printf '%s\n' "$raw" | format_listing
while IFS= read -r name; do
  [ -n "$name" ] || continue
  write_session_file "$name"
done < <(printf '%s\n' "$raw" | listing_names)
echo
echo "each is a file in the sessions folder next to this script;"
echo "open one in a terminal to attach"
