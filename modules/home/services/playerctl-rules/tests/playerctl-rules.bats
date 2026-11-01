# The REAL watcher script against a stub playerctl and pactl (see ./script.nix):
#   $ACTIONS  every verb and VOLUME=<value> the script sent, one per line
#   $POS      the row of $STATES the player is on after those verbs

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  work=$BATS_TEST_TMPDIR
  export POS=$work/pos SPOS=$work/spos LAG=$work/lag DROP=$work/drop CORK=$work/cork
  export ACTIONS=$work/actions
  export LAGSTEPS=0 LOCAL=1 STATES=/dev/null
  : >"$ACTIONS"
  echo 0 >"$POS"
  echo 0 >"$SPOS"
  echo 0 >"$LAG"
  echo 0 >"$DROP"
  echo 0 >"$CORK"
}

# A failed case shows everything the script sent, not just the count it got wrong.
teardown() {
  if [ -z "${BATS_TEST_COMPLETED:-}" ]; then
    echo "actions sent:"
    cat "$ACTIONS"
  fi
}

@test "a skip runs through back-to-back DJ X segments and stops on the song" {
  export FOLLOW_FIXTURE=$skipFollow STATES=$skipStates
  run "$skipScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'next\nnext'
  assert_equal "$(cat "$POS")" 2
}

@test "a held mute mutes once on entering DJ X and restores once on leaving it" {
  export FOLLOW_FIXTURE=$muteFollow
  run "$muteScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'VOLUME=0\nVOLUME=0.7'
}

@test "a skip the player drops is retried until the song plays, without skipping past it" {
  export FOLLOW_FIXTURE=$retryFollow STATES=$retryStates
  echo 1 >"$DROP"
  run "$skipScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'next\nnext'
  assert_equal "$(cat "$POS")" 1
}

@test "metadata trailing playback after a skip does not cause a second skip" {
  export FOLLOW_FIXTURE=$lagFollow STATES=$lagStates LAGSTEPS=3
  run "$skipScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" next
  assert_equal "$(cat "$POS")" 1
}

@test "DJ X mirrored from another Connect device is left alone on this host" {
  export FOLLOW_FIXTURE=$skipFollow STATES=$skipStates LOCAL=0
  run "$skipScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" ""
  assert_equal "$(cat "$POS")" 0
}

@test "a local stream corked across the track change still gets DJ X skipped" {
  export FOLLOW_FIXTURE=$retryFollow STATES=$retryStates
  echo 3 >"$CORK"
  run "$skipScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" next
  assert_equal "$(cat "$POS")" 1
}
