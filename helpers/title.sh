#!/usr/bin/env bash
# The terminal's title bar names the session it shows. tmux is told, on
# every attach, to keep the outer terminal's title equal to the session's
# name; it sends the title down the ssh link as any program in the
# terminal would. Told per attach rather than in a tmux config on the
# server, so the server needs nothing beyond tmux. Sourced, never executed.
#
# After the name, a dot says what the session's Claude is doing, as
# its hooks store it (see state.sh): blue working, red waiting on you,
# green done, orange stopped — a turn you broke off. At the end, since a
# tab too narrow for its title keeps the end of it. No dot is a session
# whose Claude has ended, or was started without the hooks. tmux's status
# line, at the foot of the window, takes the same colours, the blue muted,
# since only red needs you; a session without a word keeps tmux's own
# green.

# The dot, and the status line's colours, for the word on the session.
TITLE_FORMAT='#S#{?#{==:#{@claude},working}, 🔵,#{?#{==:#{@claude},waiting}, 🔴,#{?#{==:#{@claude},done}, 🟢,#{?#{==:#{@claude},stopped}, 🟠,}}}}'
STATUS_STYLE='#{?#{==:#{@claude},working},bg=colour24 fg=white,#{?#{==:#{@claude},waiting},bg=red fg=white,#{?#{==:#{@claude},done},bg=colour28 fg=white,#{?#{==:#{@claude},stopped},bg=colour208 fg=black,bg=green fg=black}}}}'

# Appended to the tmux command that attaches. The backslashed semicolons
# reach tmux as command separators after the server's shell reads them.
TMUX_TITLE_COMMANDS="\\; set-option -g set-titles on \\; set-option -g set-titles-string \"$TITLE_FORMAT\" \\; set-option -g status-style \"$STATUS_STYLE\""
