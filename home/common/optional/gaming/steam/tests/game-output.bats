# game-output against a focused-output stub that prints $FOCUSED, or fails without it.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

@test "the game gets the focused output's mode" {
  FOCUSED="DP-2 3440 1440 144" run "$gameOutput" "$reportMode"
  assert_success
  assert_line "3440 1440 144"
}

@test "without a focused output the declared primary is used" {
  run "$gameOutput" "$reportMode"
  assert_success
  assert_line "2560 1600 165"
}

@test "HDR is read from a declared output whose name contains spaces" {
  run "$gameOutput" "$reportHdr"
  assert_success
  assert_line "GAME_OUTPUT_HDR=1"
}
