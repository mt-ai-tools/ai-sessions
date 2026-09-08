#!/usr/bin/env bash
# What Tailscale knows about the server, read so the tool can say why a
# link is lost and whether the server is ready before a trip. Read only:
# nothing here configures Tailscale or depends on it. Without Tailscale on
# this machine, or without TAILSCALE_NODE in the config, every function
# here answers nothing and returns 1, and the caller goes on as if this
# file were not there. Sourced, never executed.

# Where the App Store build on macOS keeps its command, off the PATH. Taken
# from the environment when set there, so the self-check can point it at
# nothing on a machine that has the app.
TAILSCALE_APP_COMMAND="${TAILSCALE_APP_COMMAND:-/Applications/Tailscale.app/Contents/MacOS/Tailscale}"

# How long Tailscale is given to answer, in seconds. Its command waits
# forever when the app behind it is not running — seen on macOS with the
# app installed but closed — and a reason that never comes is worse than
# none. macOS has no timeout command, so the wait is kept here.
TAILSCALE_TIMEOUT=3

# The tailscale command on this machine, or nothing.
tailscale_command() {
  if command -v tailscale >/dev/null 2>&1; then printf 'tailscale'; return; fi
  if [ -x "$TAILSCALE_APP_COMMAND" ]; then printf '%s' "$TAILSCALE_APP_COMMAND"; return; fi
  return 1
}

# Tailscale's status as JSON on stdout, or 1 when the command is missing,
# fails, or does not answer in time. The command runs in the background and
# is watched in tenths of a second, then killed. Callers run under set -e,
# so a wait that reports failure is caught, or the temp file would be left.
tailscale_status_json() {
  local cmd out pid tenths status=0
  cmd="$(tailscale_command)" || return 1
  out="$(mktemp)"
  "$cmd" status --json >"$out" 2>/dev/null &
  pid=$!
  tenths=$((TAILSCALE_TIMEOUT * 10))
  while [ "$tenths" -gt 0 ] && kill -0 "$pid" 2>/dev/null; do sleep 0.1; tenths=$((tenths - 1)); done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 0.2
    kill -9 "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$out"
    return 1
  fi
  wait "$pid" || status=$?
  cat "$out"; rm -f "$out"
  return "$status"
}

# Reads Tailscale's status and sets what it says about the server into
# TS_* variables. The status is JSON, read with awk since nothing is to be
# installed: it is printed one field per line, and the server's entry is
# the one under "Peer" whose machine name, DNS name or address is the
# config's TAILSCALE_NODE. Only the fields directly in that entry are read;
# what is nested deeper is stepped over by depth.
#
#   TS_STATE       Running, or whatever Tailscale says, or empty when it
#                  did not answer at all
#   TS_FOUND       yes when the server has an entry
#   TS_ONLINE      true or false
#   TS_EXPIRED     true when the server's key has run out
#   TS_KEY_EXPIRY  when the key runs out, as a date, or empty when expiry
#                  is disabled for the server
#   TS_CUR_ADDR    the address packets take when direct, empty when relayed
#   TS_RELAY       the relay in use
#   TS_DNS_NAME    the server's full name in the tailnet
#   TS_ADDR        the server's 100.x address in the tailnet
tailscale_peer() {
  local json
  TS_STATE="" TS_FOUND="" TS_ONLINE="" TS_EXPIRED="" TS_KEY_EXPIRY="" TS_CUR_ADDR="" TS_RELAY="" TS_DNS_NAME="" TS_ADDR=""
  [ -n "${TAILSCALE_NODE:-}" ] || return 1
  tailscale_command >/dev/null || return 1
  json="$(tailscale_status_json)" || return 0
  eval "$(printf '%s\n' "$json" | awk -v node="$TAILSCALE_NODE" '
    function unquote(s) { sub(/^[^"]*"/, "", s); sub(/".*$/, "", s); return s }
    function value(line,   v) { v = line; sub(/^[^:]*:[ \t]*/, "", v); sub(/,[ \t]*$/, "", v); if (v ~ /^"/) v = unquote(v); return v }
    function q(s) { gsub(/\047/, "\047\\\047\047", s); return "\047" s "\047" }
    function matches() {
      if (hostname == node) return 1
      if (dnsname == node || dnsname == node ".") return 1
      if (index(dnsname, node ".") == 1) return 1
      if (index(" " ips " ", " " node " ")) return 1
      return 0
    }
    function emit(   n, i, parts, addr) {
      n = split(ips, parts, " "); addr = ""
      for (i = 1; i <= n; i++) if (index(parts[i], ".")) { addr = parts[i]; break }
      print "TS_FOUND=yes"
      print "TS_ONLINE=" q(online); print "TS_EXPIRED=" q(expired); print "TS_KEY_EXPIRY=" q(keyexpiry)
      print "TS_CUR_ADDR=" q(curaddr); print "TS_RELAY=" q(relay); print "TS_DNS_NAME=" q(dnsname); print "TS_ADDR=" q(addr)
    }
    BEGIN { depth = 0; peer_depth = -1; entry_depth = -1; ips_depth = -1; found = 0 }
    {
      line = $0
      if (depth == 1 && line ~ /^[ \t]*"BackendState":/) print "TS_STATE=" q(value(line))
      if (depth == 1 && line ~ /^[ \t]*"Peer":[ \t]*\{/) peer_depth = 1
      if (peer_depth == 1 && depth == 2 && entry_depth < 0 && line ~ /^[ \t]*"[^"]*":[ \t]*\{/) {
        entry_depth = 2; hostname = ""; dnsname = ""; ips = ""; online = ""; expired = "false"; keyexpiry = ""; curaddr = ""; relay = ""
      }
      if (entry_depth == 2 && depth == 3) {
        if (line ~ /^[ \t]*"HostName":/) hostname = value(line)
        else if (line ~ /^[ \t]*"DNSName":/) dnsname = value(line)
        else if (line ~ /^[ \t]*"Online":/) online = value(line)
        else if (line ~ /^[ \t]*"Expired":/) expired = value(line)
        else if (line ~ /^[ \t]*"KeyExpiry":/) keyexpiry = value(line)
        else if (line ~ /^[ \t]*"CurAddr":/) curaddr = value(line)
        else if (line ~ /^[ \t]*"Relay":/) relay = value(line)
        else if (line ~ /^[ \t]*"TailscaleIPs":[ \t]*\[/) ips_depth = 3
      }
      if (ips_depth == 3 && depth == 4 && line ~ /^[ \t]*"/) ips = ips " " unquote(line)
      opens = gsub(/[\{\[]/, "&", line); closes = gsub(/[\}\]]/, "&", line)
      depth += opens - closes
      if (ips_depth == 3 && depth <= 3) ips_depth = -1
      if (entry_depth == 2 && depth <= 2) { entry_depth = -1; if (!found && matches()) { found = 1; emit() } }
      if (peer_depth == 1 && depth <= 1) peer_depth = -1
    }
  ')"
  return 0
}

# The interface this machine's kernel would send a packet for the server
# out of, or nothing when it cannot be asked. Tailscale online on both
# ends is not the whole way: the kernel must also know to hand packets for
# the tailnet's addresses to Tailscale's interface, and that knowledge is
# a route Tailscale installs when it starts. A network service restarted
# by hand (configd on macOS, say), or another VPN taking the route, leaves
# Tailscale answering that all is well while every packet for the server
# goes out the ordinary way and is dropped. The question is asked as each
# system answers it: route on macOS, ip on Linux. Expects tailscale_peer to
# have run.
tailscale_route_interface() {
  [ -n "${TS_ADDR:-}" ] || return 1
  local iface=""
  if command -v route >/dev/null 2>&1; then
    iface="$(route -n get "$TS_ADDR" 2>/dev/null | awk '/interface:/ { print $2; exit }')"
  fi
  if [ -z "$iface" ] && command -v ip >/dev/null 2>&1; then
    iface="$(ip route get "$TS_ADDR" 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')"
  fi
  [ -n "$iface" ] || return 1
  printf '%s' "$iface"
}

# True when this machine has no route into the tailnet: the kernel would
# send packets for the server somewhere other than Tailscale's interface,
# utun on macOS and tailscale0 on Linux. False when it has one, and false
# too when the question cannot be asked, since a route that cannot be
# checked is not a route known to be missing. Sets TS_ROUTE_IFACE to the
# interface found. Expects tailscale_peer to have run.
TS_ROUTE_IFACE=""
tailscale_route_missing() {
  TS_ROUTE_IFACE="$(tailscale_route_interface)" || return 1
  case "$TS_ROUTE_IFACE" in
    utun*|tailscale*) return 1 ;;
    *) return 0 ;;
  esac
}

# Why the server is out of reach, in one sentence, as far as Tailscale can
# tell. Nothing, and 1, when Tailscale is not part of how the server is
# reached. Reads the status itself, so a caller need not.
tailscale_reason() {
  tailscale_peer || return 1
  if [ "$TS_STATE" = "NeedsLogin" ]; then
    echo "tailscale on this machine is logged out"
  elif [ "$TS_STATE" != "Running" ]; then
    echo "tailscale is not running on this machine${TS_STATE:+ (it says: $TS_STATE)}"
  elif [ "$TS_FOUND" != "yes" ]; then
    echo "the server is not in this tailnet as $TAILSCALE_NODE"
  elif [ "$TS_EXPIRED" = "true" ]; then
    echo "the server's tailscale key has expired — log in to tailscale again on the server, and disable key expiry for it in the admin console"
  elif [ "$TS_ONLINE" != "true" ]; then
    echo "the server is offline in the tailnet"
  elif tailscale_route_missing; then
    echo "the server is online, but this machine has no route into the tailnet (packets for it leave by $TS_ROUTE_IFACE) — restart tailscaled on this machine"
  else
    echo "the server is reachable in the tailnet, ssh itself is not answering"
  fi
}

# How packets reach the server: "direct", or "relayed via <relay>" when a
# firewall between the two has them go round through Tailscale's relays,
# which works but adds lag. Empty until traffic has flowed, since Tailscale
# picks the path on first contact. Expects tailscale_peer to have run.
tailscale_path() {
  [ "$TS_FOUND" = "yes" ] || return 1
  if [ -n "$TS_CUR_ADDR" ]; then echo "direct"
  elif [ -n "$TS_RELAY" ]; then echo "relayed via $TS_RELAY"
  fi
}

# Days from today until the server's key runs out, or nothing when expiry
# is disabled for it — the setting a server wants, since a key that runs
# out unattended is a server that silently stops answering. Expects
# tailscale_peer to have run. The dates are counted in days since a fixed
# day by arithmetic alone, since date reads a date differently on macOS
# and Linux.
tailscale_expiry_days() {
  [ -n "$TS_KEY_EXPIRY" ] || return 1
  local today
  today="$(date -u '+%Y-%m-%d')"
  echo $(( $(days_since_epoch "${TS_KEY_EXPIRY%%T*}") - $(days_since_epoch "$today") ))
}

# A YYYY-MM-DD date as a count of days, so two of them subtract.
days_since_epoch() {
  local y m d era yoe doy doe
  IFS=- read -r y m d <<<"$1"
  y=$((10#$y)); m=$((10#$m)); d=$((10#$d))
  [ "$m" -le 2 ] && y=$((y - 1))
  era=$(( (y >= 0 ? y : y - 399) / 400 ))
  yoe=$(( y - era * 400 ))
  doy=$(( (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1 ))
  doe=$(( yoe * 365 + yoe / 4 - yoe / 100 + doy ))
  echo $(( era * 146097 + doe - 719468 ))
}
