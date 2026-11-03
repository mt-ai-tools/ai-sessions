#!/usr/bin/env bash
# What to do when the link to the server is lost: say so, say why as far
# as Tailscale can tell, wait, and let the caller reach again. Shared by
# everything that keeps a link open — a session window, a forwarded port —
# so a lost link reads and behaves the same in each. Sourced, never
# executed; expects the config loaded and remote.sh sourced.
#
# The link to the server does not outlive a closed lid: the laptop sleeps,
# the server stops hearing from it, and ssh ends. Reaching again as soon
# as the lid opens is what puts the window back where it was. Away from
# the server's own network the link is lost for other reasons — Tailscale
# off on this machine, the server down, its key run out — and these do not
# mend in three seconds. So the wait grows while the link stays lost, and
# when the config names the server in Tailscale, what Tailscale knows
# about it is said with each wait.
#
# The loss is said once; each try after it is a line under it, ending in
# what ssh said when it failed, so a window shows one outage as one block.
. "$(dirname "${BASH_SOURCE[0]}")/tailscale.sh"

# The first wait after the link is lost, in seconds. Short, since the wait
# is what stands between an opened lid and the window's work; and the
# reach itself gives up quickly when nothing answers.
RECONNECT_SECONDS=3

# The wait doubles each time the link is lost again, up to this: a network
# down for an hour is not helped by a reach every three seconds.
RECONNECT_MAX_SECONDS=30

# Where the tries of one outage keep what they need between them: a mark
# that the link came up, and what ssh said on a try that did not. In one
# folder for the window's life, gone with it.
reconnect_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-sessions.XXXXXX")"
trap 'rm -rf "$reconnect_dir"' EXIT
reconnect_up="$reconnect_dir/up"
reconnect_said="$reconnect_dir/said"
: >"$reconnect_said"

# Makes ssh mark the link as up once it is made — before any command runs
# there, so a try that hangs or sleeps after it is still told from one that
# never got through. Passed to every ssh that keeps a link; see remote.sh.
SSH_REACH=(-o PermitLocalCommand=yes -o "LocalCommand=touch $(printf %q "$reconnect_up")")

# When the current outage began, in seconds since the epoch; empty while
# the link holds. One outage is said once, however many tries it takes.
reconnect_down_since=""

# The tries made in the current outage, and the next wait, in seconds.
reconnect_try=0
reconnect_wait_seconds=$RECONNECT_SECONDS

# A span of seconds as a person says it: 40s, 2m14s, 1h05m.
reconnect_span() {
  local s="$1"
  if [ "$s" -lt 60 ]; then printf '%ss' "$s"
  elif [ "$s" -lt 3600 ]; then printf '%sm%02ss' $((s / 60)) $((s % 60))
  else printf '%sh%02sm' $((s / 3600)) $((s % 3600 / 60)); fi
}

# Makes one reach: runs the command given — an ssh carrying SSH_REACH —
# and returns its status. While the link is up, ssh speaks to the window
# as it goes. During an outage what it says is kept, so reconnect_wait can
# say it as that try's result rather than leave it to read as the next
# one's cause; when the try ends for good, it is said as it was.
reconnect_reach() {
  local status=0
  rm -f "$reconnect_up"
  : >"$reconnect_said"
  if [ -n "$reconnect_down_since" ]; then
    "$@" 2>"$reconnect_said" || status=$?
    [ "$status" -eq "$SSH_LINK_LOST" ] || cat "$reconnect_said" >&2
  else
    "$@" || status=$?
  fi
  return "$status"
}

# Says the link is back and how long it was gone, when it was gone at all.
# For a window that shows the link coming up — a forwarded port — rather
# than handing the screen to the server at once.
reconnect_back() {
  [ -n "$reconnect_down_since" ] || return 0
  echo "ai-sessions: link to $SERVER back after $(reconnect_span $(($(date +%s) - reconnect_down_since)))"
}

# Says the loss and waits. Takes what goes on meanwhile as a phrase
# ("session notes goes on there"), which the message carries so the window
# says what it is waiting for. The first loss, or a loss after the link
# came back, starts an outage: said once, with the wait short again. Each
# try that fails within it is a line under it, carrying what ssh said.
reconnect_wait() {
  local what="$1" reason
  if [ -z "$reconnect_down_since" ] || [ -f "$reconnect_up" ]; then
    cat "$reconnect_said" >&2
    reconnect_down_since="$(date +%s)"
    reconnect_try=0
    reconnect_wait_seconds=$RECONNECT_SECONDS
    echo
    echo "ai-sessions: link to $SERVER lost — $what, ctrl-c to stop"
  else
    reconnect_try=$((reconnect_try + 1))
    if [ -s "$reconnect_said" ]; then
      awk -v first="  try $reconnect_try failed: " '{ print (NR == 1 ? first : "    ") $0 }' "$reconnect_said"
    else
      echo "  try $reconnect_try failed"
    fi
  fi
  reason="$(tailscale_reason)" || reason=""
  echo "  ${reason:+$reason — }trying again in ${reconnect_wait_seconds}s"
  sleep "$reconnect_wait_seconds"
  reconnect_wait_seconds=$((reconnect_wait_seconds * 2))
  [ "$reconnect_wait_seconds" -le "$RECONNECT_MAX_SECONDS" ] || reconnect_wait_seconds=$RECONNECT_MAX_SECONDS
}
