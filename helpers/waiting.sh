#!/usr/bin/env bash
# A session window whose session went down with the server waits for it
# to be restored and attaches again, rather than end: the window, its
# place on screen and what it scrolled back, stay. While it waits it
# leaves a mark here, so restore-sessions knows the session has a window
# already and opens no second one. Sourced, never executed; expects the
# config loaded and remote.sh sourced.

# One mark per waiting window, named for the server and the session and
# holding the window's process id: a window gone without clearing its
# mark leaves one that reads as nobody's.
WAITING_DIR="${TMPDIR:-/tmp}/ai-sessions-waiting"

# How often a waiting window asks whether its session is back, in seconds.
WAITING_SECONDS=5

# A link lost this many seconds before the server booted still counts as
# lost to that boot: ssh takes up to a minute of silence to notice, and a
# quick reboot is over by then; the two clocks may also disagree a little.
WAITING_BOOT_SLACK=300

waiting_mark() {
  printf '%s/%s' "$WAITING_DIR" "$(printf '%s\n%s' "$SERVER" "$1" | shasum | cut -c1-20)"
}

# Whether a window is waiting for this session now.
waiting_window_alive() {
  local pid
  pid="$(cat "$(waiting_mark "$1")" 2>/dev/null)" || return 1
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# Whether the server booted after the given time, less the slack: that is,
# whether the link lost then was lost to a restart.
server_booted_since() {
  local booted
  booted="$(remote_run "awk '/^btime /{print \$2}' /proc/stat 2>/dev/null || sysctl -n kern.boottime | sed 's/^.*sec = \\([0-9]*\\).*\$/\\1/'" 2>/dev/null)" || return 1
  case "$booted" in ''|*[!0-9]*) return 1 ;; esac
  [ "$booted" -ge $(($1 - WAITING_BOOT_SLACK)) ]
}

# Waits until tmux on the server runs the session again, marked meanwhile.
# Ends with ctrl-c, as any wait here does.
wait_for_restore() {
  local name="$1" mark
  mark="$(waiting_mark "$name")"
  mkdir -p "$WAITING_DIR"
  echo $$ >"$mark"
  trap 'rm -f "$mark"; rm -rf "${reconnect_dir:-}"' EXIT
  echo
  echo "ai-sessions: $SERVER restarted and session $name is not back yet — this window attaches again once it is"
  echo "  (restore-sessions brings it back, or the watch does with AUTO_RESTORE) — ctrl-c to stop"
  until remote_run "tmux has-session -t $(printf %q "=$name")" 2>/dev/null; do
    sleep "$WAITING_SECONDS"
  done
  rm -f "$mark"
}
