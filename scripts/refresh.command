#!/usr/bin/env bash
# Asks the server what it keeps running and rewrites the sessions folder to
# match: one runnable file per session. Open this in a terminal first;
# then open a session's file.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
. "$root/helpers/config.sh"
. "$root/helpers/remote.sh"
. "$root/helpers/listing.sh"
. "$root/helpers/sessions-dir.sh"

load_config
raw="$(remote_run "$(list_panes_command)")"

clear_session_files
if [ -z "$raw" ]; then
  echo "no sessions running on $SERVER"
  exit 0
fi

printf '%s\n' "$raw" | format_listing
while IFS= read -r name; do
  [ -n "$name" ] || continue
  write_session_file "$name"
done < <(printf '%s\n' "$raw" | listing_names)
echo
echo "each is now a file in $SESSIONS_DIR — open one in a terminal to attach"
