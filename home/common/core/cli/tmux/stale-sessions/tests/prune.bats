# tmux-prune-stale-sessions against a live tmux server.

setup() {
  load "$common"
  common_setup
}

teardown() {
  common_teardown
}

@test "a session seen for the first time gets a last-attached time and is kept" {
  new_session -s alpha
  "$prune"
  assert_stamped_now alpha
  assert alive alpha
}

@test "a session last attached inside the window is kept with its time" {
  new_session -s alpha
  "$prune"
  backdate alpha $((2 * day))
  local before
  before=$(stamp alpha)
  "$prune"
  assert alive alpha
  assert_equal "$(stamp alpha)" "$before"
}

@test "killing a stale session spares one whose name it prefixes" {
  new_session -s alpha
  new_session -s alp
  "$prune"
  stale alp
  "$prune"
  assert alive alpha
  run alive alp
  assert_failure
}

@test "a restore's fresh session_created does not reset the countdown" {
  new_session -s beta
  new_session -s alpha
  "$prune"
  stale beta
  # What continuum does on every boot: same names, brand new creation times.
  "${tm[@]}" kill-server
  new_session -s beta
  new_session -s alpha
  "$prune"
  run alive beta
  assert_failure
  assert alive alpha
}

@test "prune reads the last-attached time record-attach wrote for a name with spaces" {
  new_session -s "Auth service Library"
  "$recordAttach" "Auth service Library"
  assert_stamped_now "Auth service Library"
  stale "Auth service Library"
  "$prune"
  run alive "Auth service Library"
  assert_failure
}

@test "a detached session still running a command is kept and restamped" {
  new_session -s working "sleep 600"
  "$prune"
  stale working
  "$prune"
  assert alive working
  assert_stamped_now working
}

@test "a detached session sitting at a shell prompt is killed once stale" {
  new_session -s prompting
  "$prune"
  stale prompting
  "$prune"
  run alive prompting
  assert_failure
}

@test "recorded times are left alone when no tmux server is running" {
  new_session -s keeper
  "$prune"
  "$recordAttach" ghost
  cp -a "$sd" "$BATS_TEST_TMPDIR/before"
  "${tm[@]}" kill-server
  "$prune"
  run diff -r "$BATS_TEST_TMPDIR/before" "$sd"
  assert_success
}

@test "a new session does not inherit the last-attached time of a dead one with the same name" {
  # A second session so killing gamma does not take the whole server with it.
  new_session -s keeper
  new_session -s gamma
  "$prune"
  stale gamma
  "${tm[@]}" kill-session -t "=gamma"
  "$prune"
  assert_not_exists "$sd/$(key gamma)"
  new_session -s gamma
  "$prune"
  assert alive gamma
}
