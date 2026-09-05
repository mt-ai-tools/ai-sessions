#!/usr/bin/env bash
# Every reach to the server goes through here, so the connection is shaped
# in one place. Sourced, never executed.

# Keepalives ride out the short blips a laptop's link has — a roam between
# access points, a lid closed for a moment — instead of dropping the
# connection on the first missed packet. The values are seconds between
# probes and probes tolerated, so about a minute of silence is survived.
SSH_KEEPALIVE=(-o ServerAliveInterval=15 -o ServerAliveCountMax=4)

# A reach that gets no answer gives up after this many seconds instead of
# hanging: a laptop just woken has no network for a moment, and a reach
# made then must end so the next one can be made.
SSH_CONNECT=(-o ConnectTimeout=10)

# ssh's own exit status when it could not reach the server or lost it on
# the way. Any other status was handed back by the command run there.
SSH_LINK_LOST=255

# Runs a command on the server and returns its output. No terminal: for
# listings and checks. The server's login banner is informational and
# would land in every listing, so only errors are let through here; the
# terminal path below keeps the banner, since a person is reading it.
remote_run() {
  ssh -o LogLevel=ERROR "${SSH_KEEPALIVE[@]}" "${SSH_CONNECT[@]}" "$SERVER" "$@"
}

# Wipes the screen and its scrollback, then homes the cursor. Spelled out
# rather than left to the clear command, whose output differs between
# terminals. Used before the first thing a script shows, so whatever the
# terminal printed while starting it is gone.
wipe() { printf '\033[2J\033[3J\033[H'; }

# Resolves a folder as the server sees it — relative to the login user's
# home, a leading ~ expanded, or absolute — to its absolute path there.
# Fails, saying so, when the folder does not exist: tmux would otherwise
# start the session in the home folder without a word.
resolve_remote_dir() {
  local dir="$1" resolved
  resolved="$(remote_run "d=$(printf %q "$dir"); case \"\$d\" in '~'|'~/'*) d=\"\$HOME\${d#'~'}\";; esac; cd -- \"\$d\" 2>/dev/null && pwd")" || true
  if [ -z "$resolved" ]; then
    echo "ai-sessions: no such folder on the server: $dir" >&2
    return 1
  fi
  printf '%s' "$resolved"
}

# Hands your terminal to a command on the server. For attaching
# to a session, which needs a terminal on both ends.
remote_terminal() {
  ssh -t "${SSH_KEEPALIVE[@]}" "${SSH_CONNECT[@]}" "$SERVER" "$@"
}
