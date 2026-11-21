#!/usr/bin/env bash
# With AUTO_RESTORE="true", the watch brings back the server's Claude
# sessions by itself after the server restarts: restore-sessions, said yes
# to, once per boot. Sourced by watch-sessions, never executed; the config
# is already loaded and remote.sh sourced.
#
# A boot is told by the server's own boot id, asked on each round. The
# first round that reaches a boot not seen before runs the restore, and
# the boot is written down here, so it is never run twice for one boot: a
# session you end on purpose stays ended. There is no wait to tune: a
# server just up answers ssh when it is ready, and until then a round
# fails as any lost link does and the next round asks again.
#
# Nothing runs while no watch does. The tool still starts nothing on its
# own account; the watch you leave open is what does it.

AUTO_RESTORE_MARK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.restored-boot"
AUTO_RESTORE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/restore-sessions"

# The server's boot id: Linux's own, or on macOS when the kernel booted.
# Fails when the server cannot be reached.
server_boot_id() {
  remote_run 'cat /proc/sys/kernel/random/boot_id 2>/dev/null || sysctl -n kern.boottime' 2>/dev/null
}

# What the last automatic restore said, for the watch's header: when, and
# its closing line. Empty when none has run.
auto_restore_last() {
  [ -f "$AUTO_RESTORE_MARK" ] && sed -n 2p "$AUTO_RESTORE_MARK"
  return 0
}

# Runs the restore when the server is on a boot not seen before. Says
# nothing when the setting is off, the boot is known, or the server does
# not answer.
auto_restore() {
  [ "${AUTO_RESTORE:-}" = "true" ] || return 0
  local boot mark out
  boot="$(server_boot_id)" || return 0
  [ -n "$boot" ] || return 0
  mark="$SERVER $boot"
  [ "$(head -n 1 "$AUTO_RESTORE_MARK" 2>/dev/null)" = "$mark" ] && return 0
  echo "ai-sessions: $SERVER is on a boot not seen before — restoring its Claude sessions"
  out="$(bash "$AUTO_RESTORE_SCRIPT" --yes 2>&1)" || true
  printf '%s\n' "$out"
  # Lost before the plan was read: nothing was tried, so the next round
  # tries again rather than take the boot as done.
  case "$out" in *"could not reach $SERVER"*) return 0 ;; esac
  printf '%s\n%s  %s\n' "$mark" "$(date '+%m-%d %H:%M')" "$(printf '%s\n' "$out" | tail -n 1)" >"$AUTO_RESTORE_MARK"
  echo
}
