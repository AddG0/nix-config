# decky-migrate-shared-data from the old shared state dir into the boot user's data dir.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_require_minimum_version 1.5.0

  state=$BATS_TEST_TMPDIR/state
  data=$BATS_TEST_TMPDIR/home/.local/share/decky
  mkdir -p "$state/settings/Deckify" "$state/data/Deckify" "$state/themes/Kept" "$data/themes/Kept"
  echo creds >"$state/settings/Deckify/settings.json"
  echo '{}' >"$state/settings/loader.json"
  echo shared >"$state/themes/Kept/theme.json"
}

@test "plugin settings and data move into the boot user's dir" {
  "$migrate" "$state" "$data"
  assert_equal "$(cat "$data/settings/Deckify/settings.json")" creds
  assert_dir_exists "$data/data/Deckify"
  assert_not_exists "$state/data"
}

@test "loader.json stays shared" {
  "$migrate" "$state" "$data"
  assert_file_exists "$state/settings/loader.json"
  assert_not_exists "$data/settings/loader.json"
}

@test "a theme the user already has is neither overwritten nor dropped" {
  "$migrate" "$state" "$data"
  assert_equal "$(cat "$state/themes/Kept/theme.json")" shared
  assert_not_exists "$data/themes/Kept/theme.json"
}

@test "a second run succeeds once the data has moved" {
  "$migrate" "$state" "$data"
  run "$migrate" "$state" "$data"
  assert_success
}

@test "a missing boot data dir does not stop Decky's start" {
  run "$migrate" "$state" "$BATS_TEST_TMPDIR/absent/.local/share/decky"
  assert_success
  assert_file_exists "$state/settings/Deckify/settings.json"
}

@test "a failed move is reported, keeps its source, and does not stop the rest" {
  blocked=$BATS_TEST_TMPDIR/blocked
  mkdir -p "$state/logs/Deckify" "$state/data/Deckcord" "$blocked"
  touch "$blocked/logs"
  run --separate-stderr "$migrate" "$state" "$blocked"
  assert_failure
  assert_stderr --partial "decky: could not move $state/logs/Deckify to $blocked/logs/Deckify"
  assert_dir_exists "$state/logs/Deckify"
  assert_dir_exists "$blocked/data/Deckcord"
}
