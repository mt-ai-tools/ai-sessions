#!/usr/bin/env bash
# Every reach to the server goes through here, so the connection is shaped
# in one place. Sourced, never executed.

# Keepalives ride out the short blips a laptop's link has — a roam between
# access points, a lid closed for a moment — instead of dropping the
# connection on the first missed packet. The values are seconds between
# probes and probes tolerated, so about a minute of silence is survived.
SSH_KEEPALIVE=(-o ServerAliveInterval=15 -o ServerAliveCountMax=4)

# Runs a command on the server and returns its output. No terminal: for
# listings and checks. The server's login banner is informational and
# would land in every listing, so only errors are let through here; the
# terminal path below keeps the banner, since a person is reading it.
remote_run() {
  ssh -o LogLevel=ERROR "${SSH_KEEPALIVE[@]}" "$SERVER" "$@"
}

# Hands your terminal to a command on the server. For attaching
# to a session, which needs a terminal on both ends.
remote_terminal() {
  ssh -t "${SSH_KEEPALIVE[@]}" "$SERVER" "$@"
}
