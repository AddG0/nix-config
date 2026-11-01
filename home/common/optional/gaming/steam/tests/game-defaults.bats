# game-defaults runs a game through the listed-game wrapper chain, adding
# gamescope only on request. Each stub wrapper appends its name to $CHAIN; the
# game stub writes its arguments to $ARGV and the offload env to $OFFLOAD_SEEN.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export CHAIN=$BATS_TEST_TMPDIR/chain
  export ARGV=$BATS_TEST_TMPDIR/argv
  export OFFLOAD_SEEN=$BATS_TEST_TMPDIR/offload
}

@test "without --gamescope the game runs under game-output and gamemoderun only" {
  run "$gameDefaults" "$game" "Steam App" -novr --gamescope
  assert_success
  assert_equal "$(paste -sd' ' "$CHAIN")" "game-output gamemoderun"
}

@test "the game's own arguments pass through untouched, even one spelled --gamescope" {
  run "$gameDefaults" "$game" "Steam App" -novr --gamescope
  assert_success
  assert_equal "$(cat "$ARGV")" "$(printf '%s\n' "Steam App" -novr --gamescope)"
}

@test "the GPU offload env reaches the game without --gamescope" {
  run "$gameDefaults" "$game" -novr
  assert_success
  assert_equal "$(cat "$OFFLOAD_SEEN")" 1
}

@test "--gamescope adds gamescope innermost in the chain" {
  run "$gameDefaults" --gamescope "$game" -novr
  assert_success
  assert_equal "$(paste -sd' ' "$CHAIN")" "game-output gamemoderun gamescope"
}

@test "--gamescope is consumed, not passed on to the game" {
  run "$gameDefaults" --gamescope "$game" -novr
  assert_success
  assert_equal "$(cat "$ARGV")" "-novr"
}

@test "the GPU offload env reaches the game under gamescope" {
  run "$gameDefaults" --gamescope "$game" -novr
  assert_success
  assert_equal "$(cat "$OFFLOAD_SEEN")" 1
}
