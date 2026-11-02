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

# A turn can end while agents it started work on in the background, or
# while commands those agents started still run. Claude takes up their
# results when they finish, so the session is working until then, however
# still its screen. Each Stop hook is told what still runs; commands
# Claude itself left running, a server say, it is not waiting on, and they
# do not count. Something killed with no hook to say so would hold the
# session working for good, so after this many minutes without a Stop
# hook the screen decides again.
BACKGROUND_MINUTES=60

# The tmux options, all on the session, never global, so each session
# shows its own Claude and no other: the word; whether a Stop hook has run
# since the last work; the transcript, as the Stop hook was told it; the
# watch's process, so a hook starts one only where none runs; the
# background commands agents started, by id; and when a Stop hook last
# found background work running, empty when it found none.
STATE_OPTION='@claude'
STOP_OPTION='@claude_stop'
TRANSCRIPT_OPTION='@claude_transcript'
WATCH_OPTION='@claude_watch'
SHELLS_OPTION='@claude_agent_shells'
BACKGROUND_OPTION='@claude_background'

# What every hook starts with: the session Claude runs in, which tmux
# names in the environment of everything started inside it. Outside tmux
# there is nothing to tell.
HOOK_START='[ -n "$TMUX_PANE" ] || exit 0; P="$TMUX_PANE"'

# What Claude hands the hook, in $i, and whether it came from one of its
# agents rather than Claude itself: an agent's hooks carry its id.
READ_INPUT='i="$(cat)"'
FROM_AGENT='printf %s "$i" | grep -Eq '"'"'"agent_id": *"'"'"''

# An agent's tool that left a command running in the background — a shell
# command, a monitor — names it in its response; the name is kept.
KEEP_AGENT_SHELL='if '"$FROM_AGENT"'; then
  x="$(printf %s "$i" | sed -En '"'"'s/.*"(backgroundTaskId|taskId)": *"([^"]*)".*/\2/p'"'"')"
  [ -z "$x" ] || tmux set-option -t "$P" '"$SHELLS_OPTION"' "$(tmux show-options -v -t "$P" '"$SHELLS_OPTION"' 2>/dev/null) $x" >/dev/null 2>&1
fi'

# Reads what a Stop hook is told still runs: an agent, or a command an
# agent started, and the time is stored; nothing, and it is cleared.
NOTE_BACKGROUND='r="$(printf %s "$i" | grep -o '"'"'"id": *"[^"]*", *"type": *"[^"]*", *"status": *"running"'"'"')"; b=""
if printf %s "$r" | grep -q '"'"'"type": *"subagent"'"'"'; then b=1; else
  o=" $(tmux show-options -v -t "$P" '"$SHELLS_OPTION"' 2>/dev/null) "
  for x in $(printf %s "$r" | grep '"'"'"type": *"shell"'"'"' | sed '"'"'s/^"id": *"\([^"]*\)".*/\1/'"'"'); do
    case "$o" in *" $x "*) b=1;; esac
  done
fi
if [ -n "$b" ]; then tmux set-option -t "$P" '"$BACKGROUND_OPTION"' "$(date +%s)" >/dev/null 2>&1
else tmux set-option -u -t "$P" '"$BACKGROUND_OPTION"' >/dev/null 2>&1; fi'

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
  b="$(tmux show-options -v -t "$P" '"$BACKGROUND_OPTION"' 2>/dev/null)"
  [ -z "$b" ] || [ $(($(date +%s) - b)) -ge $(('"$BACKGROUND_MINUTES"' * 60)) ] || continue
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
# An agent's work leaves the Stop hook be: Claude's own turn ended all the
# same, and what the agents do holds the session working only as long as
# it runs.
WORK_BODY='s=working; '"$SET_STATE"'
'"$FROM_AGENT"' || tmux set-option -t "$P" '"$STOP_OPTION"' 0 >/dev/null 2>&1
'"$ENSURE_WATCH"'
exit 0'
WORK="$HOOK_START"'; '"$READ_INPUT"'
'"$WORK_BODY"

# A tool done: work, and a command an agent left running is kept.
TOOL_DONE="$HOOK_START"'; '"$READ_INPUT"'
'"$KEEP_AGENT_SHELL"'
'"$WORK_BODY"


# A Stop hook: the turn may be ending, which the watch will tell. Until
# then the session stays working.
STOP="$HOOK_START"'; '"$READ_INPUT"'
t="$(printf %s "$i" | sed -n '"'"'s/.*"transcript_path": *"\([^"]*\)".*/\1/p'"'"')"
'"$NOTE_BACKGROUND"'
s=working; '"$SET_STATE"'
tmux set-option -t "$P" '"$STOP_OPTION"' 1 \; set-option -t "$P" '"$TRANSCRIPT_OPTION"' "$t" >/dev/null 2>&1
'"$ENSURE_WATCH"'
exit 0'

# A tool about to run is work, unless the tool is itself a question to
# you — a question asked, a plan put up for approval: the hook sees the
# tool's name in what Claude hands it.
TOOL="$HOOK_START"'; '"$READ_INPUT"'
if printf %s "$i" | grep -Eq '"'"'"tool_name": *"(AskUserQuestion|ExitPlanMode)"'"'"'; then s=waiting; '"$SET_STATE"'; exit 0; fi
'"$WORK_BODY"

# An agent stopping is told what still runs, as a Stop hook is; it changes
# nothing else, since Claude takes up what the agent did after.
AGENT_STOP="$HOOK_START"'; '"$READ_INPUT"'
'"$NOTE_BACKGROUND"'
exit 0'

# A permission asked, or a dialog put up: waiting on you.
WAIT="$HOOK_START"'; s=waiting; '"$SET_STATE"'; exit 0'

# A conversation resumed is done until you write: its last turn ended
# before it was resumed.
RESUMED="$HOOK_START"'; tmux set-option -u -t "$P" '"$BACKGROUND_OPTION"' \; set-option -u -t "$P" '"$SHELLS_OPTION"' >/dev/null 2>&1; s=done; '"$SET_STATE"'; exit 0'

# Claude ending: the word is taken away, the watch with it.
END="$HOOK_START"'; tmux set-option -u -t "$P" '"$STATE_OPTION"' \; set-option -u -t "$P" '"$BACKGROUND_OPTION"' \; set-option -u -t "$P" '"$SHELLS_OPTION"' >/dev/null 2>&1; exit 0'

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
  printf '{"hooks":{%s,%s,%s,%s,%s,%s,%s,%s}}' \
    "$(hook_entry UserPromptSubmit "$WORK")" \
    "$(hook_entry PreToolUse "$TOOL")" \
    "$(hook_entry PostToolUse "$TOOL_DONE")" \
    "$(hook_entry Notification "$WAIT" 'permission_prompt|elicitation_dialog')" \
    "$(hook_entry Stop "$STOP")" \
    "$(hook_entry SubagentStop "$AGENT_STOP")" \
    "$(hook_entry SessionStart "$RESUMED" resume)" \
    "$(hook_entry SessionEnd "$END")"
}
