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

# The table's headings, in column order: name, folder, what runs there,
# whether someone has it open.
LISTING_HEADINGS="SESSION FOLDER RUNS OPENED"

# The space between columns.
LISTING_GAP="   "

# Turns tmux's lines into the table you read, headed. Each column is as
# wide as its longest cell, heading included, so nothing is cut and nothing
# wastes room. The home folder is shortened to ~ on the way. Reads stdin,
# writes stdout. Nothing else happens here.
format_listing() {
  awk -F "$LISTING_TAB" -v headings="$LISTING_HEADINGS" -v gap="$LISTING_GAP" '
    function pad(n,   s) { s = ""; while (n-- > 0) s = s " "; return s }
    BEGIN {
      cols = split(headings, head, " ")
      for (i = 1; i <= cols; i++) { cell[0, i] = head[i]; width[i] = length(head[i]) }
      rows = 0
    }
    $1 == "" { next }
    {
      rows++
      folder = $2
      sub(/^\/(home|Users)\/[^\/]+\//, "~/", folder)
      sub(/^\/(home|Users)\/[^\/]+$/, "~", folder)
      cell[rows, 1] = $1; cell[rows, 2] = folder; cell[rows, 3] = $3
      cell[rows, 4] = ($4 != "0") ? "yes" : "-"
      for (i = 1; i <= cols; i++) if (length(cell[rows, i]) > width[i]) width[i] = length(cell[rows, i])
    }
    END {
      for (r = 0; r <= rows; r++) {
        line = ""
        for (i = 1; i <= cols; i++) {
          line = line cell[r, i]
          if (i < cols) line = line pad(width[i] - length(cell[r, i])) gap
        }
        print line
      }
    }'
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
