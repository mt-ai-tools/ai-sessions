#!/usr/bin/env bash
# The sessions folder: one runnable file per session, written by refresh
# and opened in a terminal. Sourced, never executed.

. "$(dirname "${BASH_SOURCE[0]}")/listing.sh"

SESSIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sessions"

# No suffix: a bare file with its executable bit is what a file manager on
# macOS or Linux runs in a terminal; a .sh is a text file to macOS.
SESSION_FILE_SUFFIX=""

# Writes the file for one session. Each file only names its session and
# hands over to the attach helper, so what attaching means has one home
# and a stale file from an earlier version still does the current thing.
#
# The helper runs as the file's child, not in its place. Some terminals
# (macOS Terminal among them) put the name of the command a tab runs after
# the title tmux sets, and the tab shows the end when it is short of room:
# with the file staying the command, that end is the session's own name.
#
# Usage: <tmux name> [file name] [start time]. The file is named after the
# session unless told otherwise, and dated when the session started when
# that is given.
write_session_file() {
  local name="$1" file="$SESSIONS_DIR/${2:-$1}$SESSION_FILE_SUFFIX"
  mkdir -p "$SESSIONS_DIR"
  cat >"$file" <<EOT
#!/usr/bin/env bash
# Written by refresh for the session named below; the next refresh rewrites
# it. Open in a terminal to attach.
"\$(dirname "\${BASH_SOURCE[0]}")/../helpers/attach.sh" $(printf %q "$name")
EOT
  chmod +x "$file"
  [ -z "${3:-}" ] || date_file "$file" "$3"
}

# Dates a file at a moment given in seconds since the epoch, so the folder
# sorts by when each session started. touch takes the date the same way on
# macOS and Linux; turning the seconds into it is date -r on macOS and
# date -d @ on Linux. It sets the modified date, and macOS moves the created
# date back with it, since a file cannot be modified before it was created.
# A moment that is not a number, or a date that cannot read it, leaves the
# file as it was: the date is a convenience, never a reason to fail.
date_file() {
  local file="$1" seconds="$2" stamp
  case "$seconds" in *[!0-9]*|'') return 0 ;; esac
  stamp="$(date -r "$seconds" '+%Y%m%d%H%M.%S' 2>/dev/null || date -d "@$seconds" '+%Y%m%d%H%M.%S' 2>/dev/null)" || return 0
  touch -t "$stamp" "$file" 2>/dev/null || true
}

# The file name for a session, given its place counting from the oldest,
# and its tmux name. With NUMBER_SESSIONS on, the place goes in front, so
# the folder lists the sessions in the order they were started; the place
# moves up when an older session ends. The tmux name itself never changes.
session_file_name() {
  if [ "${NUMBER_SESSIONS:-}" = "true" ]; then
    printf '%03d %s' "$1" "$2"
  else
    printf '%s' "$2"
  fi
}

# Writes the file of every session, given the server's listing on stdin,
# and prints the file name of the one named, if given and listed.
write_session_files() {
  local only="${1:-}" place=0 name created file
  while IFS="$LISTING_TAB" read -r name created; do
    place=$((place + 1))
    file="$(session_file_name "$place" "$name")"
    write_session_file "$name" "$file" "$created"
    [ "$name" != "$only" ] || printf '%s' "$file"
  done < <(listing_by_age)
}

# Clears the folder so it holds only what the server reported this time.
clear_session_files() {
  mkdir -p "$SESSIONS_DIR"
  rm -f "$SESSIONS_DIR"/*"$SESSION_FILE_SUFFIX"
}
