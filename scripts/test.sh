#!/usr/bin/env bash
# The checks, needing nothing installed: the config loads or fails the right
# way, the listing reads as a table, a session file is written to attach by
# name, and refresh reaches the server through ssh and fills the folder.
# The server is a fake ssh on the PATH answering with canned tmux output.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tab=$'\t'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1"; exit 1; }
ok() { echo "ok: $1"; }

# A copy of the tool with its own config, so your real config
# and real sessions folder never take part.
cp -R "$root/helpers" "$root/scripts" "$root/config.sample" "$tmp/"
tool="$tmp"

# --- config
out="$(bash -c ". '$tool/helpers/config.sh' && load_config" 2>&1)" && fail "missing config must fail"
case "$out" in *config.sample*) ;; *) fail "missing config must point at the sample" ;; esac
printf '# nothing\n' >"$tool/config"
bash -c ". '$tool/helpers/config.sh' && load_config" 2>/dev/null && fail "config without SERVER must fail"
printf 'SERVER="dev@fake"\n' >"$tool/config"
out="$(bash -c ". '$tool/helpers/config.sh' && load_config && printf '%s' \"\$SERVER\"")"
[ "$out" = "dev@fake" ] || fail "complete config must load SERVER"
ok "config"

# --- listing
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'notes${tab}/home/me/notes${tab}claude${tab}0' | format_listing")"
case "$out" in SESSION*FOLDER*RUNS*OPENED*) ;; *) fail "table must be headed (got '$out')" ;; esac
case "$out" in *notes*~/notes*claude*) ;; *) fail "listing row not formatted (got '$out')" ;; esac
case "$out" in *" -") ;; *) fail "unattached must show as -" ;; esac
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'notes${tab}/x${tab}claude${tab}1' | format_listing")"
case "$out" in *yes) ;; *) fail "attached must say yes" ;; esac
# Deeper folders keep every level below the home.
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'notes${tab}/home/me/a/b${tab}claude${tab}0' | format_listing")"
case "$out" in *"~/a/b"*) ;; *) fail "home shortening must keep deeper levels (got '$out')" ;; esac
# Columns are as wide as their longest cell, heading included, plus the gap:
# every line puts the folder at the same offset.
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'a${tab}/x${tab}claude${tab}0' 'a-much-longer-name${tab}/y${tab}sh${tab}1' | format_listing")"
offsets="$(printf '%s\n' "$out" | awk 'NR == 1 { print index($0, "FOLDER") } NR == 2 { print index($0, "/x") } NR == 3 { print index($0, "/y") }' | sort -u | wc -l | tr -d ' ')"
[ "$offsets" = "1" ] || fail "columns must line up across heading and rows (got '$out')"
case "$out" in *"a-much-longer-name   /y"*) ;; *) fail "gap after the longest cell must be exactly three spaces (got '$out')" ;; esac
out="$(bash -c ". '$root/helpers/listing.sh' && list_panes_command")"
case "$out" in *"tmux list-panes -a -F"*"|| true") ;; *) fail "server asked in tmux's format, quiet without a server" ;; esac
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'notes${tab}/a${tab}claude${tab}0' 'recipes${tab}/b${tab}claude${tab}0' | filter_listing 'recipes other'")"
case "$out" in recipes*) ;; *) fail "filter must keep only the named sessions (got '$out')" ;; esac
case "$out" in *notes*) fail "filter must drop sessions not named" ;; esac
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'notes${tab}/a${tab}claude${tab}0' 'recipes${tab}/b${tab}claude${tab}0' | filter_listing ''")"
case "$out" in *notes*recipes*) ;; *) fail "an empty filter must keep everything" ;; esac
ok "listing"

# --- session file
bash -c ". '$tool/helpers/sessions-dir.sh' && write_session_file notes"
[ -x "$tool/sessions/notes.sh" ] || fail "session file must be written and runnable"
grep -q "attach.sh" "$tool/sessions/notes.sh" || fail "session file must hand over to the attach helper"
grep -q "notes" "$tool/sessions/notes.sh" || fail "session file must carry its name"
ok "session file"

# --- refresh, with a fake ssh answering for the server
mkdir "$tmp/fakebin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' $'notes\t/home/me/notes\tclaude\t0\nrecipes\t/home/me/recipes\tclaude\t1' >"$tmp/fakebin/ssh"
chmod +x "$tmp/fakebin/ssh"
refresh() { PATH="$tmp/fakebin:$PATH" bash -c ". '$tool/helpers/config.sh' && load_config && export SERVER TMUX_SESSIONS=\${TMUX_SESSIONS:-} && bash '$tool/helpers/refresh.sh'"; }
out="$(refresh)"
case "$out" in *notes*recipes*) ;; *) fail "refresh must print the table (got '$out')" ;; esac
[ -x "$tool/sessions/notes.sh" ] && [ -x "$tool/sessions/recipes.sh" ] || fail "refresh must write one file per session"
printf '#!/usr/bin/env bash\nprintf ""\n' >"$tmp/fakebin/ssh"
out="$(refresh)"
case "$out" in *"no tmux sessions running on dev@fake"*) ;; *) fail "no sessions must be said plainly" ;; esac
[ -e "$tool/sessions/notes.sh" ] && fail "refresh must clear files for sessions that are gone"
ok "refresh"

# --- the clock: the default holds when the config is silent, the config wins
out="$(bash -c ". '$tool/helpers/config.sh' && load_config && printf '%s' \"\$REFRESH_SECONDS\"")"
[ "$out" = "30" ] || fail "refresh seconds must default to half a minute (got '$out')"
printf 'SERVER="dev@fake"\nREFRESH_SECONDS=5\n' >"$tool/config"
out="$(bash -c ". '$tool/helpers/config.sh' && load_config && printf '%s' \"\$REFRESH_SECONDS\"")"
[ "$out" = "5" ] || fail "config must set the refresh seconds (got '$out')"
ok "clock"

# --- watch: one round against the fake server prints the header and the
# table. Started in the background and stopped after a moment, since it
# never ends on its own.
printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' $'notes\t/home/me/notes\tclaude\t0' >"$tmp/fakebin/ssh"
printf 'SERVER="dev@fake"\nREFRESH_SECONDS=1\n' >"$tool/config"
PATH="$tmp/fakebin:$PATH" bash "$tool/scripts/watch-sessions.sh" >"$tmp/watch.out" 2>&1 &
watch_pid=$!
sleep 2
kill "$watch_pid" 2>/dev/null || true
wait "$watch_pid" 2>/dev/null || true
out="$(tr -d '\033' <"$tmp/watch.out")"
case "$out" in *"tmux sessions on:"*"dev@fake"*) ;; *) fail "watch must print its header (got '$out')" ;; esac
case "$out" in *"refresh rate:"*"1s"*) ;; *) fail "watch must show the refresh rate" ;; esac
case "$out" in *SESSION*notes*~/notes*) ;; *) fail "watch must print the table (got '$out')" ;; esac
ok "watch"

# --- new: the folder is resolved on the server before the session starts,
# and a folder the server does not have stops it. The fake ssh answers the
# resolving with a path and records the tmux command it is handed.
cat >"$tmp/fakebin/ssh" <<'EOR'
#!/usr/bin/env bash
cmd="${*: -1}"
case "$cmd" in
  *"cd -- "*) [ -f "$FAKE_NO_SUCH_DIR" ] || printf '/home/me/notes\n' ;;
  *"tmux new-session"*) printf '%s\n' "$cmd" >"$FAKE_TMUX_LOG" ;;
esac
EOR
chmod +x "$tmp/fakebin/ssh"
export FAKE_TMUX_LOG="$tmp/tmux.log" FAKE_NO_SUCH_DIR="$tmp/no-such-dir"
printf 'SERVER="dev@fake"\n' >"$tool/config"
rm -rf "$tool/sessions"
printf 'notes\n~/notes\n' | PATH="$tmp/fakebin:$PATH" bash "$tool/scripts/new-session.sh" >/dev/null 2>&1 || fail "new must start a session in an existing folder"
grep -q -- "-c /home/me/notes" "$FAKE_TMUX_LOG" || fail "new must hand tmux the resolved folder (got '$(cat "$FAKE_TMUX_LOG")')"
[ -x "$tool/sessions/notes.sh" ] || fail "new must write the session's file"
touch "$FAKE_NO_SUCH_DIR"; rm -f "$FAKE_TMUX_LOG"; rm -rf "$tool/sessions"
out="$(printf 'notes\nnope\n' | PATH="$tmp/fakebin:$PATH" bash "$tool/scripts/new-session.sh" 2>&1)" && fail "new must refuse a folder the server does not have"
case "$out" in *"no such folder on the server: nope"*) ;; *) fail "new must say which folder is missing (got '$out')" ;; esac
[ -e "$FAKE_TMUX_LOG" ] && fail "new must not start a session in a missing folder"
[ -e "$tool/sessions/notes.sh" ] && fail "new must not write a file for a session it did not start"
ok "new"

echo "all checks passed"
