# Behavior tests for the config: a missing file names the sample and fails,
# a file naming no server fails, and a complete one loads.

setup() {
  lib="$BATS_TEST_DIRNAME/../lib/config.sh"
  # A copy of the lib in a scratch tree, so the test decides what config
  # sits beside it rather than whatever the developer has there.
  mkdir -p "$BATS_TEST_TMPDIR/tool/lib"
  cp "$lib" "$BATS_TEST_TMPDIR/tool/lib/config.sh"
  touch "$BATS_TEST_TMPDIR/tool/config.sample"
  scratch_lib="$BATS_TEST_TMPDIR/tool/lib/config.sh"
}

@test "a missing config fails and points at the sample" {
  run bash -c ". '$scratch_lib' && load_config"
  [ "$status" -eq 1 ]
  [[ "$output" == *"config.sample"* ]]
}

@test "a config naming no server fails" {
  printf '# nothing here\n' >"$BATS_TEST_TMPDIR/tool/config"
  run bash -c ". '$scratch_lib' && load_config"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SERVER"* ]]
}

@test "a complete config loads the server" {
  printf 'SERVER="dev@example"\n' >"$BATS_TEST_TMPDIR/tool/config"
  run bash -c ". '$scratch_lib' && load_config && printf '%s' \"\$SERVER\""
  [ "$status" -eq 0 ]
  [ "$output" = "dev@example" ]
}
