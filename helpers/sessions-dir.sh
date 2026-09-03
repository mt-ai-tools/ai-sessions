#!/usr/bin/env bash
# The sessions folder: one runnable file per session, written by refresh
# and opened by a double-click. Sourced, never executed.

SESSIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sessions"

# The suffix that makes a file open in a terminal on a double-click.
SESSION_FILE_SUFFIX=".command"

# Writes the file for one session. Each file only names its session and
# hands over to the attach helper, so what attaching means has one home
# and a stale file from an earlier version still does the current thing.
write_session_file() {
  local name="$1" file="$SESSIONS_DIR/$1$SESSION_FILE_SUFFIX"
  mkdir -p "$SESSIONS_DIR"
  cat >"$file" <<EOT
#!/usr/bin/env bash
# Written by refresh for the session named below; the next refresh rewrites
# it. Double-click to attach.
exec "\$(dirname "\${BASH_SOURCE[0]}")/../helpers/attach.sh" $(printf %q "$name")
EOT
  chmod +x "$file"
}

# Clears the folder so it holds only what the server reported this time.
clear_session_files() {
  mkdir -p "$SESSIONS_DIR"
  rm -f "$SESSIONS_DIR"/*"$SESSION_FILE_SUFFIX"
}
