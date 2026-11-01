# The module's client-attached hook, taken from the rendered config, against a live tmux.

setup() {
  load "$common"
  common_setup
  # The isolated module graph catches an accidental hook replacement.
  grep -E "^set-hook -ag client-attached" "$hostConf" >"$BATS_TEST_TMPDIR/hooks.conf"
}

teardown() {
  exec 5>&-
  common_teardown
}

@test "this module's client-attached hook survives ssh's" {
  local want
  want=$(grep -c . "$BATS_TEST_TMPDIR/hooks.conf")
  assert [ "$want" -ge 2 ]
  new_session -s probe -x 80 -y 24
  "${tm[@]}" source-file "$BATS_TEST_TMPDIR/hooks.conf"
  run "${tm[@]}" show-hooks -g
  assert_success
  assert_equal "$(grep -c "^client-attached" <<<"$output")" "$want"
  assert_output --partial "tmux-record-session-attach"
}

@test "attaching to a session with spaces records the whole name" {
  new_session -s probe -x 80 -y 24
  "${tm[@]}" source-file "$BATS_TEST_TMPDIR/hooks.conf"
  "${tm[@]}" rename-session -t "=probe" "Auth service Library"
  rm -f "$sd"/*
  mkfifo "$BATS_TEST_TMPDIR/fifo"
  # script(1) only hands its child a pty when its own stdin is not /dev/null.
  script -q -c "${tm[*]} attach -t '=Auth service Library'" /dev/null \
    <"$BATS_TEST_TMPDIR/fifo" >/dev/null 2>&1 3>&- &
  exec 5>"$BATS_TEST_TMPDIR/fifo"
  # Hooks run backgrounded, so poll rather than guess a sleep.
  for _ in $(seq 100); do
    [ -n "$(stamp "Auth service Library")" ] && break
    sleep 0.1
  done
  assert_stamped_now "Auth service Library"
}
