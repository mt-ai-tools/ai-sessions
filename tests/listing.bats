# Behavior tests for the listing: tmux's lines become a readable table with
# the home folder shortened and the attached flag spelled out, and the names
# come out alone for picking.

setup() {
  lib="$BATS_TEST_DIRNAME/../lib/listing.sh"
  tab=$'\t'
}

@test "a pane line becomes a row with the home folder shortened" {
  run bash -c ". '$lib' && printf '%s\n' 'hub${tab}/home/dev/mf-dev-hub${tab}claude${tab}0' | format_listing"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hub"* ]]
  [[ "$output" == *"~/mf-dev-hub"* ]]
  [[ "$output" == *"claude"* ]]
  [[ "$output" =~ [[:space:]]-$ ]]
}

@test "an attached session says so" {
  run bash -c ". '$lib' && printf '%s\n' 'hub${tab}/home/dev/mf-dev-hub${tab}claude${tab}1' | format_listing"
  [[ "$output" == *"attached"* ]]
}

@test "names come out alone, one per line" {
  run bash -c ". '$lib' && printf '%s\n' 'hub${tab}/a${tab}claude${tab}0' 'demo${tab}/b${tab}claude${tab}0' | listing_names"
  [ "$output" = $'hub\ndemo' ]
}

@test "the server is asked in tmux's own format and told to stay quiet without a server" {
  run bash -c ". '$lib' && list_panes_command"
  [[ "$output" == *"tmux list-panes -a -F"* ]]
  [[ "$output" == *"session_name"* ]]
  [[ "$output" == *"|| true"* ]]
}
