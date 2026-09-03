#!/usr/bin/env bash
# What the server is asked for and how the answer is read — in one place, so
# the question and the reading cannot drift apart. Sourced, never executed.

# The field separator between tmux's columns: a tab, since a path may hold
# spaces and a tab is the one character tmux will not put in one.
LISTING_TAB=$'\t'

# The tmux format string the server is asked for, one line per pane. The
# attached flag says whether someone is already looking at the session.
TMUX_PANE_FORMAT="#{session_name}${LISTING_TAB}#{pane_current_path}${LISTING_TAB}#{pane_current_command}${LISTING_TAB}#{session_attached}"

# The command run on the server. Exit 0 with no output when tmux has no
# server running, since that is "no sessions", not an error.
list_panes_command() {
  printf 'tmux list-panes -a -F %q 2>/dev/null || true' "$TMUX_PANE_FORMAT"
}

# Turns tmux's lines into the table you read: name, folder with
# the home shortened, what runs there, and whether it is already attached.
# Reads stdin, writes stdout. Nothing else happens here.
format_listing() {
  local name path command attached
  while IFS="$LISTING_TAB" read -r name path command attached; do
    [ -n "$name" ] || continue
    printf '%-14s %-40s %-10s %s\n' "$name" "${path/#\/home\/*\//~/}" "$command" \
      "$([ "$attached" != "0" ] && echo attached || echo -)"
  done
}

# The names alone, one per line.
listing_names() {
  cut -f1
}
