# Behavior tests for the entry: the listing reaches the server through ssh
# and comes back as a table, no sessions is said plainly, and an unknown
# verb prints usage and fails. The server is a fake ssh on the PATH that
# answers with canned tmux output.

setup() {
  # A copy of the tool with its own config, so the developer's real config
  # never takes part.
  cp -R "$BATS_TEST_DIRNAME/.." "$BATS_TEST_TMPDIR/tool"
  rm -f "$BATS_TEST_TMPDIR/tool/config"
  printf 'SERVER="dev@fake"\n' >"$BATS_TEST_TMPDIR/tool/config"
  entry="$BATS_TEST_TMPDIR/tool/bin/sessions"

  mkdir "$BATS_TEST_TMPDIR/fakebin"
  fake_ssh="$BATS_TEST_TMPDIR/fakebin/ssh"
}

fake_ssh_answering() { # canned tmux output -> a fake ssh printing it
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "$1" >"$fake_ssh"
  chmod +x "$fake_ssh"
}

@test "list prints the server's sessions as a table" {
  fake_ssh_answering $'hub\t/home/dev/mf-dev-hub\tclaude\t0'
  run env PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" "$entry" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"hub"* ]]
  [[ "$output" == *"~/mf-dev-hub"* ]]
}

@test "no sessions is said plainly" {
  fake_ssh_answering ""
  run env PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" "$entry" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no sessions running on dev@fake"* ]]
}

@test "an unknown verb prints usage and fails" {
  run "$entry" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"sessions list"* ]]
}
