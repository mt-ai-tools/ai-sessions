#!/usr/bin/env bash
# Where the config lives and what it must hold — in one place, so every
# entry reads the same file and fails the same way. Sourced, never executed.

CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/../config"
CONFIG_SAMPLE="$(dirname "${BASH_SOURCE[0]}")/../config.sample"

# Loads the config into the caller's shell. Missing or incomplete, it says
# where the sample is and fails: a tool that guessed a server would connect
# somewhere the developer did not choose.
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
}
