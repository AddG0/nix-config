# The REAL watcher against stand-in playerctl and pactl (see ./script.nix), on
# DJ X sessions copied from logs. Each fixture says when it was recorded.
#   $ACTIONS  every verb sent to the player and every change to its stream mute, one per line
#   $POS      the queue row the player is on

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  work=$BATS_TEST_TMPDIR
  export POS=$work/pos SPOS=$work/spos LAG=$work/lag DROP=$work/drop CORK=$work/cork CONSUMED=$work/consumed
  export ACTIONS=$work/actions
  export LAGSTEPS=0 LOCAL=1 STATES=/dev/null
  : >"$ACTIONS"
  echo 0 >"$POS"
  echo 0 >"$SPOS"
  echo 0 >"$LAG"
  echo 0 >"$DROP"
  echo 0 >"$CORK"
}

# A failed case shows everything sent to the player, not just the value it got wrong.
teardown() {
  if [ -z "${BATS_TEST_COMPLETED:-}" ]; then
    echo "actions sent:"
    cat "$ACTIONS"
    echo "now playing: $(now_playing)"
  fi
}

now_playing() { "$playerctl" metadata | cut -f1; }

start_on_row() { echo "$1" >"$POS"; }

# Spotify stand-in: presses copied from a real session, replayed. If one fails,
# the stand-in no longer behaves as Spotify did, and the watcher cases below mean nothing.

@test "Spotify stand-in: Next on Up next skips the announced song as well" {
  export STATES=$upNextQueue
  start_on_row 1
  "$playerctl" next
  assert_equal "$(now_playing)" "Song After - Skipped Past"
}

@test "Spotify stand-in: Previous after skipping Up next plays the announced song" {
  export STATES=$upNextQueue
  start_on_row 1
  "$playerctl" next
  "$playerctl" previous
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "Spotify stand-in: Next on Up next sometimes lands on the announced song" {
  export STATES=$upNextQueue NEXT_ON_UP_NEXT=lands-on-announced
  start_on_row 1
  "$playerctl" next
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "Spotify stand-in: Previous on Up next goes back, then Next passes the spent segment" {
  export STATES=$upNextQueue
  start_on_row 1
  "$playerctl" previous
  assert_equal "$(now_playing)" "Song Before - Played Last"
  "$playerctl" next
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "Spotify stand-in: Previous at the start of an announced song restarts it" {
  export STATES=$upNextQueue
  start_on_row 2
  "$playerctl" previous
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "skipping an Up next segment still plays the song it announced, silencing the hop" {
  export FOLLOW_FIXTURE=$upNextFollow STATES=$upNextQueue
  start_on_row 1
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nprevious\nstream unmuted'
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "a skip that already lands on the announced song stays there, without Previous" {
  export FOLLOW_FIXTURE=$upNextFollow STATES=$upNextQueue NEXT_ON_UP_NEXT=lands-on-announced
  start_on_row 1
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nstream unmuted'
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "without an announced-track rule, a skip moves on and never presses Previous" {
  export FOLLOW_FIXTURE=$upNextFollow STATES=$upNextQueue
  start_on_row 1
  run "$plainSkipScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nstream unmuted'
  assert_equal "$(now_playing)" "Song After - Skipped Past"
}

@test "skipping a Welcome segment goes straight on, since it announces no song" {
  export FOLLOW_FIXTURE=$welcomeFollow STATES=$welcomeQueue
  start_on_row 1
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nstream unmuted'
  assert_equal "$(now_playing)" "First Song - After Welcome"
}

@test "a Welcome is skipped again after a real song, though every Welcome shares one trackid" {
  export FOLLOW_FIXTURE=$reusedIdFollow STATES=$reusedIdQueue
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nstream unmuted\nstream muted\nnext\nstream unmuted'
  assert_equal "$(now_playing)" "Song After - Skipped Past"
}

@test "back-to-back Up next segments are both skipped, then the last one's song plays" {
  export FOLLOW_FIXTURE=$backToBackFollow STATES=$backToBackQueue
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nnext\nprevious\nstream unmuted'
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "a skip Spotify ignores is retried, and the announced song still plays" {
  export FOLLOW_FIXTURE=$ignoredSkipFollow STATES=$ignoredSkipQueue
  echo 1 >"$DROP"
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nnext\nprevious\nstream unmuted'
  assert_equal "$(now_playing)" "Announced Song - DJ Pick"
}

@test "when the player refuses every skip, the segment stays muted until its song starts" {
  export FOLLOW_FIXTURE=$refusedSkipsFollow STATES=$upNextQueue
  start_on_row 1
  echo 4 >"$DROP"
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nnext\nnext\nnext\nstream unmuted'
  assert_output --partial 'the player ignored every skip; staying muted until "DJ X - Up next" ends'
}

@test "metadata still showing the segment just after a skip does not cause a second skip" {
  export FOLLOW_FIXTURE=$welcomeFollow STATES=$welcomeQueue LAGSTEPS=3
  start_on_row 1
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nstream unmuted'
  assert_equal "$(now_playing)" "First Song - After Welcome"
}

@test "DJ X mirrored from another Connect device is left alone on this host" {
  export FOLLOW_FIXTURE=$upNextFollow STATES=$upNextQueue LOCAL=0
  start_on_row 1
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" ""
  assert_equal "$(now_playing)" "DJ X - Up next"
}

@test "a local stream corked across the track change still gets DJ X skipped" {
  export FOLLOW_FIXTURE=$welcomeFollow STATES=$welcomeQueue
  start_on_row 1
  echo 3 >"$CORK"
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nstream unmuted'
  assert_equal "$(now_playing)" "First Song - After Welcome"
}

@test "a DJ segment still loading after quick skips is skipped once its audio starts" {
  export FOLLOW_FIXTURE=$welcomeFollow STATES=$welcomeQueue
  start_on_row 1
  echo 16 >"$CORK"
  run "$spotifyScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nnext\nstream unmuted'
  assert_equal "$(now_playing)" "First Song - After Welcome"
}

@test "the mute action mutes once across Welcome turning into Up next, and unmutes once on the song" {
  export FOLLOW_FIXTURE=$muteFollow
  run "$muteScript"
  assert_success
  assert_equal "$(cat "$ACTIONS")" $'stream muted\nstream unmuted'
}
