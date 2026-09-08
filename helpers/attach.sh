#!/usr/bin/env bash
# Puts this terminal into one session on the server, and keeps it there.
# Every session file runs this with its own name; nothing else attaches.
#
# The link to the server does not outlive a closed lid: the laptop sleeps,
# the server stops hearing from it, and ssh ends. The session on the
# server does not notice. So when ssh ends that way, this waits and
# attaches again, as often as it takes — see reconnect.sh for the wait —
# and the window is back in its session moments after the lid opens.
# Detaching on purpose, or the session being gone from the server, ends
# it as before.
#
# A link lost mid-session also leaves this terminal as the session had it,
# since what switches the terminal's modes on is the program on the server,
# and it never got to switch them off. That is put right before the loss
# is said: see settle_terminal.
#
# Usage: <name>
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/config.sh"
. "$here/remote.sh"
. "$here/title.sh"
. "$here/reconnect.sh"

# Puts the terminal back to how it was before the session had it. A program
# in the session — claude among them — switches on mouse reporting and
# bracketed paste, and switches them off again on its way out; a link lost
# mid-session gives it no way out. The terminal then goes on reporting the
# mouse, and every move types a report such as ^[[<35;62;43M into this
# window, where it shows as garbage and piles up as input that the next
# ssh would hand to the session as keystrokes. So the reporting is switched
# off, the cursor shown, and whatever has piled up is read and thrown
# away. Only in a terminal: with the output captured, as by the
# self-check, there is nothing to settle. The pending input is read with
# the terminal set to answer at once with what it has, since bash 3.2 has
# no read that waits a fraction of a second.
settle_terminal() {
  local saved
  if [ -t 1 ]; then printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?2004l\033[?25h'; fi
  [ -t 0 ] || return 0
  saved="$(stty -g)" || return 0
  stty -icanon -echo min 0 time 0
  while [ -n "$(dd bs=4096 count=1 2>/dev/null)" ]; do :; done
  stty "$saved"
}

name="${1:?attach.sh <name>}"
load_config
while true; do
  status=0
  SECONDS=0
  remote_terminal "tmux attach -t $(printf %q "$name") $TMUX_TITLE_COMMANDS" || status=$?
  [ "$status" -eq "$SSH_LINK_LOST" ] || exit "$status"
  settle_terminal
  reconnect_wait "$SECONDS" "session $name goes on there"
done
