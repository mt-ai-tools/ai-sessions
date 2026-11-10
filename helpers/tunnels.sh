#!/usr/bin/env bash
# The tunnels folder: files carried between this machine and the server.
# What comes from the server lands in tunnels/from-server; what is put in
# tunnels/to-server goes to the server. receive-files and send-files use
# this; nothing else touches the folder. Sourced, never executed.
#
# Files ride as a tar stream through the same ssh every other reach takes,
# so the server needs nothing beyond what it already has: no rsync, no scp
# configuration, no port of its own.

TUNNELS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tunnels"
FROM_SERVER_DIR="$TUNNELS_DIR/from-server"
TO_SERVER_DIR="$TUNNELS_DIR/to-server"

# Finder's own file, never carried either way.
TUNNEL_SKIP=".DS_Store"

# Makes both folders, so a fresh clone has them the first time either
# script runs. They are ignored by version control, like the sessions.
make_tunnel_dirs() {
  mkdir -p "$FROM_SERVER_DIR" "$TO_SERVER_DIR"
}

# Asks for a folder on the server, shown the same examples add-claude
# shows: relative to the login user's home, with ~, or absolute.
ask_remote_folder() {
  local prompt="$1" dir
  echo "Examples:" >&2
  printf '%-24s %s\n' "my-folder" "/home/my-user/my-folder" \
                       "~/my-folder" "/home/my-user/my-folder" \
                       "/home/my-user/my-folder" "/home/my-user/my-folder" >&2
  echo >&2
  read -r -p "$prompt" dir || dir=""
  [ -n "$dir" ] || { echo "ai-sessions: a folder is needed" >&2; return 1; }
  printf '%s' "$dir"
}

# Asks copy or move, one key, C or M in either case, and prints which.
# Any other key is a no: nothing is carried.
ask_copy_or_move() {
  local key=""
  read -r -n 1 -p "Press (C) to copy or press (M) to move " key || true
  echo >&2
  case "$key" in
    c|C) printf 'copy' ;;
    m|M) printf 'move' ;;
    *) echo "ai-sessions: neither C nor M — nothing carried" >&2; return 1 ;;
  esac
}

# Options for this machine's tar when it packs: macOS's tar would
# otherwise add its ._ files and extended attributes, which a Linux tar
# on the server unpacks as clutter or warns about.
local_pack_options() {
  if tar --version 2>/dev/null | grep -q bsdtar; then
    printf '%s\n' --no-mac-metadata --no-xattrs
  fi
}

# The names directly inside to-server, one per line, Finder's file left out.
to_server_entries() {
  local path
  for path in "$TO_SERVER_DIR"/* "$TO_SERVER_DIR"/.[!.]* "$TO_SERVER_DIR"/..?*; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    [ "${path##*/}" = "$TUNNEL_SKIP" ] && continue
    printf '%s\n' "${path##*/}"
  done
}
