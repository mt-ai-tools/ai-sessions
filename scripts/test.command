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

# A copy of the tool with its own config, so the developer's real config
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
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'hub${tab}/home/dev/mf-dev-hub${tab}claude${tab}0' | format_listing")"
case "$out" in *hub*~/mf-dev-hub*claude*) ;; *) fail "listing row not formatted (got '$out')" ;; esac
case "$out" in *" -") ;; *) fail "unattached must show as -" ;; esac
out="$(bash -c ". '$root/helpers/listing.sh' && printf '%s\n' 'hub${tab}/x${tab}claude${tab}1' | format_listing")"
case "$out" in *attached) ;; *) fail "attached must say so" ;; esac
out="$(bash -c ". '$root/helpers/listing.sh' && list_panes_command")"
case "$out" in *"tmux list-panes -a -F"*"|| true") ;; *) fail "server asked in tmux's format, quiet without a server" ;; esac
ok "listing"

# --- session file
bash -c ". '$tool/helpers/sessions-dir.sh' && write_session_file hub"
[ -x "$tool/sessions/hub.command" ] || fail "session file must be written and runnable"
grep -q "attach.sh" "$tool/sessions/hub.command" || fail "session file must hand over to the attach helper"
grep -q "hub" "$tool/sessions/hub.command" || fail "session file must carry its name"
ok "session file"

# --- refresh, with a fake ssh answering for the server
mkdir "$tmp/fakebin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' $'hub\t/home/dev/mf-dev-hub\tclaude\t0\ndemo\t/home/dev/demo\tclaude\t1' >"$tmp/fakebin/ssh"
chmod +x "$tmp/fakebin/ssh"
out="$(PATH="$tmp/fakebin:$PATH" bash "$tool/scripts/refresh.command")"
case "$out" in *hub*demo*) ;; *) fail "refresh must print the table (got '$out')" ;; esac
[ -x "$tool/sessions/hub.command" ] && [ -x "$tool/sessions/demo.command" ] || fail "refresh must write one file per session"
printf '#!/usr/bin/env bash\nprintf ""\n' >"$tmp/fakebin/ssh"
out="$(PATH="$tmp/fakebin:$PATH" bash "$tool/scripts/refresh.command")"
case "$out" in *"no sessions running on dev@fake"*) ;; *) fail "no sessions must be said plainly" ;; esac
[ -e "$tool/sessions/hub.command" ] && fail "refresh must clear files for sessions that are gone"
ok "refresh"

echo "all checks passed"
