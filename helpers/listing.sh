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

# The table's columns, sized to fit an 80-column window with room to spare:
# name, folder, what runs there, whether someone is attached.
LISTING_ROW='%-16s %-36s %-8s %s\n'

# The table's heading, in the same shape as its rows.
listing_heading() {
  printf "$LISTING_ROW" "SESSION" "FOLDER" "RUNS" "ATTACHED"
}

# Turns tmux's lines into the table you read: name, folder with the home
# shortened, what runs there, and whether it is already attached. Reads
# stdin, writes stdout. Nothing else happens here.
format_listing() {
  local name path command attached
  while IFS="$LISTING_TAB" read -r name path command attached; do
    [ -n "$name" ] || continue
    printf "$LISTING_ROW" "$name" "${path/#\/home\/*\//~/}" "$command" \
      "$([ "$attached" != "0" ] && echo yes || echo -)"
  done
}

# The names alone, one per line.
listing_names() {
  cut -f1
}

# Keeps only the lines whose tmux session is among the names given,
# separated by spaces. Given nothing, keeps everything: an empty choice is no choice.
# Reads stdin, writes stdout.
filter_listing() {
  local wanted="$1" name rest
  [ -n "$wanted" ] || { cat; return; }
  while IFS="$LISTING_TAB" read -r name rest; do
    case " $wanted " in *" $name "*) printf '%s%s%s\n' "$name" "$LISTING_TAB" "$rest" ;; esac
  done
}
