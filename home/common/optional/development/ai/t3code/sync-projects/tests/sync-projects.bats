# The REAL sync-projects.sh against stub gwq, sqlite3 and t3: gwq lists
# known-present, known-missing and new-repo as clones plus one worktree;
# sqlite3 reports known-present, known-missing and $HAND_REGISTERED as
# registered; t3 appends its arguments to $T3_LOG. Every refute_line sits beside
# an assert_line of the same verb, so a drift in t3's argument format fails.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export PATH=$stubPath:$PATH
  export T3_LOG=$BATS_TEST_TMPDIR/t3.log
  export T3CODE_STATE_DB=$BATS_TEST_TMPDIR/statev2.sqlite
  export TEST_BASE=$BATS_TEST_TMPDIR/repos
  export HOME=$BATS_TEST_TMPDIR/home
  # Never created, so only the exclusion keeps it from being pruned.
  export HAND_REGISTERED=$BATS_TEST_TMPDIR/hand-registered
  export T3CODE_SYNC_UNMANAGED=$HAND_REGISTERED
  touch "$T3_LOG" "$T3CODE_STATE_DB"
  # known-missing and new-repo stay absent: one is pruned, the other only needs to be unregistered.
  mkdir -p "$TEST_BASE/known-present" "$HOME"
}

sync_projects() {
  bash "$syncScript"
  run cat "$T3_LOG"
}

@test "a clone that is not registered yet is added" {
  sync_projects
  assert_line "project add $TEST_BASE/new-repo"
}

@test "an already-registered clone is not added again" {
  sync_projects
  assert_line "project add $TEST_BASE/new-repo"
  refute_line "project add $TEST_BASE/known-present"
}

@test "a gwq worktree is never registered as a project" {
  sync_projects
  assert_line "project add $TEST_BASE/new-repo"
  refute_line "project add $TEST_BASE/worktree"
}

@test "a registered project whose directory is gone is removed" {
  sync_projects
  assert_line "project remove $TEST_BASE/known-missing"
}

@test "a registered project whose directory still exists is kept" {
  sync_projects
  assert_line "project remove $TEST_BASE/known-missing"
  refute_line "project remove $TEST_BASE/known-present"
}

@test "the unmanaged checkout is kept even though its directory is missing" {
  sync_projects
  assert_line "project remove $TEST_BASE/known-missing"
  refute_line "project remove $HAND_REGISTERED"
}

@test "without an unmanaged checkout configured, the same missing path is removed" {
  unset T3CODE_SYNC_UNMANAGED
  sync_projects
  assert_line "project remove $HAND_REGISTERED"
}
