#!/usr/bin/env bash
# Where the config lives and what it must hold — in one place, so every
# script reads the same file and fails the same way. Sourced, never executed.

CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/../config"
CONFIG_SAMPLE="$(dirname "${BASH_SOURCE[0]}")/../config.sample"

# How often the listen script asks the server again, in seconds, unless the
# config says otherwise. A minute is slow enough to cost nothing and fast
# enough that a session started elsewhere is not long in appearing.
DEFAULT_REFRESH_SECONDS=60

# Loads the config into the caller's shell. Missing or incomplete, it says
# where the sample is and fails: a tool that guessed a server would connect
# somewhere you did not choose.
load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ai-sessions: no config at $CONFIG_FILE — copy $CONFIG_SAMPLE there and fill it in" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
  if [ -z "${SERVER:-}" ]; then
    echo "ai-sessions: $CONFIG_FILE names no SERVER — see $CONFIG_SAMPLE" >&2
    return 1
  fi
  REFRESH_SECONDS="${REFRESH_SECONDS:-$DEFAULT_REFRESH_SECONDS}"
}
