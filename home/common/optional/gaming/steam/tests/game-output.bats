# game-output reads HDR from a declared output whose name has spaces, as
# laptop panels' desc: names do. hyprctl is stubbed to fail, so the declared
# primary is the target.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

@test "HDR is read from a declared output whose name contains spaces" {
  run "$gameOutput" "$reportHdr"
  assert_success
  assert_line "GAME_OUTPUT_HDR=1"
}
