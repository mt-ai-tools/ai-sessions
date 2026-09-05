#!/usr/bin/env bash
# The terminal's title bar names the session it shows. tmux is told, on
# every attach, to keep the outer terminal's title equal to the session's
# name; it sends the title down the ssh link as any program in the
# terminal would. Told per attach rather than in a tmux config on the
# server, so the server needs nothing beyond tmux. Sourced, never executed.

# Appended to the tmux command that attaches. The backslashed semicolons
# reach tmux as command separators after the server's shell reads them.
TMUX_TITLE_COMMANDS='\; set-option -g set-titles on \; set-option -g set-titles-string "#S"'
