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

# The shell, run on the server, that turns a folder as given — relative to
# the login user's home, a leading ~ expanded, or absolute — into $d.
remote_dir_expr() {
  printf 'd=%q; case "$d" in %s) d="$HOME${d#%s}";; esac' "$1" "'~'|'~/'*" "'~'"
}

# Resolves a folder as the server sees it to its absolute path there.
# Fails when the folder does not exist, for the caller to say so: tmux
# would otherwise start the session in the home folder without a word.
# Returns 255, as ssh does, when the server could not be reached, so a
# lost link is never taken for a missing folder.
resolve_remote_dir() {
  local resolved status=0
  resolved="$(remote_run "$(remote_dir_expr "$1"); cd -- \"\$d\" 2>/dev/null && pwd")" || status=$?
  [ "$status" -eq "$SSH_LINK_LOST" ] && return "$status"
  [ -n "$resolved" ] || return 1
  printf '%s' "$resolved"
}

# Creates a folder on the server, given the way resolve_remote_dir takes
# it, with any folders above it that are missing too.
make_remote_dir() {
  remote_run "$(remote_dir_expr "$1"); mkdir -p -- \"\$d\""
}

# Hands your terminal to a command on the server. For attaching to a
# session, which needs a terminal on both ends. Nothing else rides on this
# link: a port is brought over by a link of its own, below.
remote_terminal() {
  ssh -t "${SSH_KEEPALIVE[@]}" "${SSH_CONNECT[@]}" "$SERVER" "$@"
}

# Whether a string is a port number.
is_port() {
  case "$1" in *[!0-9]*|'') return 1 ;; esac
  [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# Whether something on this machine already answers on a port. Asked by
# connecting to it, which bash can do without anything installed.
port_in_use() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

# Brings one port of the server's to this machine, the same number on both
# ends, and holds the link until it ends. Says when the port is in place,
# which ssh itself never does: the server is asked to say a word, and ssh
# runs a command only once its forwards are up, so the word's arrival
# means the port is. Then the link is held by waiting on the server for
# as long as it lasts. Returns ssh's own status: 255 when the link could
# not be made or was lost, at once when the port could not be set up.
remote_forward() {
  local port="$1"
  ssh -o LogLevel=ERROR "${SSH_KEEPALIVE[@]}" "${SSH_CONNECT[@]}" -o ExitOnForwardFailure=yes \
    -L "$port:localhost:$port" "$SERVER" 'echo up; while :; do sleep 3600; done' \
    | { IFS= read -r _ && echo "port $port on the server is localhost:$port here — close this window to let it go"; cat >/dev/null; }
}
