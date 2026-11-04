# The REAL sync-projects.sh against stub gwq, sqlite3 and t3: gwq lists
# known-present, known-missing, new-repo and $SPECIAL_REPO as clones plus one worktree;
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
  export SPECIAL_REPO="$TEST_BASE/repo's"
  printf -v ESCAPED_SPECIAL_REPO '%q' "$SPECIAL_REPO"
  export ESCAPED_SPECIAL_REPO
  export HOME=$BATS_TEST_TMPDIR/home
  # Never created, so only the exclusion keeps it from being pruned.
  export HAND_REGISTERED=$BATS_TEST_TMPDIR/hand-registered
  export T3CODE_SYNC_UNMANAGED=$HAND_REGISTERED
  export REGISTER_NEW_REPO=0
  export SINGLE_PROJECT=0
  export T3_FAIL_COMMAND=
  touch "$T3_LOG" "$T3CODE_STATE_DB"
  # Missing registered and unregistered paths exercise pruning and path forwarding.
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

@test "a clone path containing an apostrophe is passed unchanged" {
  sync_projects
  assert_line "project add $SPECIAL_REPO"
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

@test "succeeds when every clone is already registered" {
  export REGISTER_NEW_REPO=1
  run bash "$syncScript"
  assert_success
}

@test "reports changed paths and the resulting project count" {
  run bash "$syncScript"
  assert_success
  assert_line "Added: $TEST_BASE/new-repo"
  assert_line "Added: $ESCAPED_SPECIAL_REPO"
  assert_line "Removed: $TEST_BASE/known-missing"
  assert_line "4 projects synced (2 added, 1 removed)"
}

@test "a non-interactive no-op stays quiet" {
  export REGISTER_NEW_REPO=1
  mkdir -p "$TEST_BASE/known-missing" "$TEST_BASE/new-repo" "$SPECIAL_REPO"
  run bash "$syncScript"
  assert_success
  assert_output ""
}

@test "an interactive no-op reports the registered project count" {
  export REGISTER_NEW_REPO=1
  mkdir -p "$TEST_BASE/known-missing" "$TEST_BASE/new-repo" "$SPECIAL_REPO"
  run script -qec "bash $syncScript" /dev/null
  assert_success
  assert_output --partial "5 projects already in sync"
}

@test "a failed add emits no success output" {
  export T3_FAIL_COMMAND="project add $TEST_BASE/new-repo"
  run bash "$syncScript"
  assert_failure 42
  refute_output --partial "Added: $TEST_BASE/new-repo"
  refute_output --partial "projects synced"
}

@test "a failed removal emits no success output" {
  export REGISTER_NEW_REPO=1
  mkdir -p "$TEST_BASE/new-repo" "$SPECIAL_REPO"
  export T3_FAIL_COMMAND="project remove $TEST_BASE/known-missing"
  run bash "$syncScript"
  assert_failure 42
  refute_output --partial "Removed: $TEST_BASE/known-missing"
  refute_output --partial "projects synced"
}

@test "an interactive no-op uses singular project grammar" {
  export SINGLE_PROJECT=1
  run script -qec "bash $syncScript" /dev/null
  assert_success
  assert_output --partial "1 project already in sync"
}
