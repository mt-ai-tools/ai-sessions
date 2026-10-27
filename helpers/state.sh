#!/usr/bin/env bash
# Each session says what its Claude is doing: working, waiting on you,
# done, or stopped — a turn you broke off with escape. Claude says most of
# it itself, through hooks it runs at those moments, and each hook stores
# the word on the session's tmux options; the title bar and tmux's status
# line show it, see title.sh. The hooks are handed to Claude as it starts,
# so the server keeps no settings for them, and they join any hooks of the
# user's or a project's own rather than replace them. They print nothing
# and always succeed: Claude reads what a hook prints, and these have
# nothing to tell it. Sourced, never executed.
#
# When a turn is over, no hook can say. The Stop hooks run as a turn
# reaches its end, but another Stop hook — the user's or a project's — may
# run for minutes after ours, or send Claude back to work; a message sent
# while Claude was busy starts the moment the turn ends, with no hook of
# its own; and a turn broken off with escape runs no hook at all. What
# does show it is the screen: while Claude works, its spinner redraws the
# window every moment, never a second apart, and idle, it is redrawn every
# ten seconds or so at most. So while the session is working, a watch
# looks at when its window last changed, and once it has been still this
# many seconds, the turn is over: done if a Stop hook has run since the
# last work, stopped if not, or if the transcript says it was broken off.
QUIET_SECONDS=5

# The tmux options, all on the session, never global, so each session
# shows its own Claude and no other: the word; whether a Stop hook has run
# since the last work; the transcript, as the Stop hook was told it; and
# the watch's process, so a hook starts one only where none runs.
STATE_OPTION='@claude'
STOP_OPTION='@claude_stop'
TRANSCRIPT_OPTION='@claude_transcript'
WATCH_OPTION='@claude_watch'

# What every hook starts with: the session Claude runs in, which tmux
# names in the environment of everything started inside it. Outside tmux
# there is nothing to tell.
HOOK_START='[ -n "$TMUX_PANE" ] || exit 0; P="$TMUX_PANE"'

# Stores the word in $s.
SET_STATE='tmux set-option -t "$P" '"$STATE_OPTION"' "$s" >/dev/null 2>&1'

# Whether the turn in transcript $t was broken off: its last message is
# the one Claude records when you press escape mid-turn. What follows a
# message in the transcript is bookkeeping, and is passed over.
INTERRUPTED_TEST='tail -n 30 "$t" 2>/dev/null | grep '"'"'^{"parentUuid"'"'"' | grep -v '"'"'"type":"system"'"'"' | tail -n 1 | grep -qF "[Request interrupted by user"'

# The watch, every two seconds for as long as the session is working. It
# ends by itself the moment the session is anything else, or gone.
WATCH_LOOP='while sleep 2; do
  [ "$(tmux show-options -v -t "$P" '"$STATE_OPTION"' 2>/dev/null)" = working ] || break
  a="$(tmux display-message -p -t "$P" "#{window_activity}" 2>/dev/null)"; [ -n "$a" ] || break
  [ $(($(date +%s) - a)) -ge '"$QUIET_SECONDS"' ] || continue
  s=stopped
  if [ "$(tmux show-options -v -t "$P" '"$STOP_OPTION"' 2>/dev/null)" = 1 ]; then
    s=done; t="$(tmux show-options -v -t "$P" '"$TRANSCRIPT_OPTION"' 2>/dev/null)"
    if '"$INTERRUPTED_TEST"'; then s=stopped; fi
  fi
  '"$SET_STATE"'; break
done'

# Starts the watch unless one already runs. It lets go of Claude's output
# at once, so the hook returns as soon as it has started it: the
# redirections are on the subshell that is put in the background, and on
# nothing around it, which would keep the hook's output open as long.
ENSURE_WATCH='w="$(tmux show-options -v -t "$P" '"$WATCH_OPTION"' 2>/dev/null)"
if [ -z "$w" ] || ! kill -0 "$w" 2>/dev/null; then
  ( '"$WATCH_LOOP"' ) </dev/null >/dev/null 2>&1 &
  tmux set-option -t "$P" '"$WATCH_OPTION"' "$!" >/dev/null 2>&1
fi'

# Work: the word, a Stop hook no longer the last thing seen, and the watch.
WORK="$HOOK_START"'
s=working; '"$SET_STATE"'
tmux set-option -t "$P" '"$STOP_OPTION"' 0 >/dev/null 2>&1
'"$ENSURE_WATCH"'
exit 0'

# A Stop hook: the turn may be ending, which the watch will tell. Until
# then the session stays working.
STOP="$HOOK_START"'
t="$(sed -n '"'"'s/.*"transcript_path": *"\([^"]*\)".*/\1/p'"'"')"
s=working; '"$SET_STATE"'
tmux set-option -t "$P" '"$STOP_OPTION"' 1 \; set-option -t "$P" '"$TRANSCRIPT_OPTION"' "$t" >/dev/null 2>&1
'"$ENSURE_WATCH"'
exit 0'

# A tool about to run is work, unless the tool is itself a question to
# you — a question asked, a plan put up for approval: the hook sees the
# tool's name in what Claude hands it.
TOOL="$HOOK_START"'
if grep -Eq '"'"'"tool_name": *"(AskUserQuestion|ExitPlanMode)"'"'"'; then s=waiting; '"$SET_STATE"'; exit 0; fi
'"${WORK#"$HOOK_START"}"

# A permission asked, or a dialog put up: waiting on you.
WAIT="$HOOK_START"'; s=waiting; '"$SET_STATE"'; exit 0'

# A conversation resumed is done until you write: its last turn ended
# before it was resumed.
RESUMED="$HOOK_START"'; s=done; '"$SET_STATE"'; exit 0'

# Claude ending: the word is taken away, the watch with it.
END="$HOOK_START"'; tmux set-option -u -t "$P" '"$STATE_OPTION"' >/dev/null 2>&1; exit 0'

# A string as JSON has it, newlines included.
json_string() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}

# One hook entry: an event, the matcher if any, and the command it runs.
hook_entry() {
  local matcher=""
  [ -z "${3:-}" ] || matcher="\"matcher\":$(json_string "$3"),"
  printf '"%s":[{%s"hooks":[{"type":"command","command":%s}]}]' "$1" "$matcher" "$(json_string "$2")"
}

# The settings Claude is started with. The notice Claude gives after a
# minute of quiet is left out of the notifications, so a finished turn
# stays done.
claude_state_settings() {
  printf '{"hooks":{%s,%s,%s,%s,%s,%s,%s}}' \
    "$(hook_entry UserPromptSubmit "$WORK")" \
    "$(hook_entry PreToolUse "$TOOL")" \
    "$(hook_entry PostToolUse "$WORK")" \
    "$(hook_entry Notification "$WAIT" 'permission_prompt|elicitation_dialog')" \
    "$(hook_entry Stop "$STOP")" \
    "$(hook_entry SessionStart "$RESUMED" resume)" \
    "$(hook_entry SessionEnd "$END")"
}
