#!/usr/bin/env bash
# Puts this terminal into one session on the server. Every session file
# runs this with its own name; nothing else attaches.
#
# Usage: <name>
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/config.sh"
. "$here/remote.sh"

name="${1:?attach.sh <name>}"
load_config
remote_terminal "tmux attach -t $(printf %q "$name")"
