# The REAL ghq-gitlab-group.sh reconciling a group folder holding a live clone with
# a linked worktree (and a repo nested in it), a gone clone, and a gone clone with
# a linked worktree. ./script.nix's stub glab answers 404 for everything but the live one.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  group_dir=$BATS_TEST_TMPDIR/ghq/gitlab.com/my-org/team
  export TEST_GHQ_ROOT=$BATS_TEST_TMPDIR/ghq TEST_GLAB_LOG=$BATS_TEST_TMPDIR/glab.log
  linked_worktree primary-repo feature-branch
  mkdir -p "$group_dir/primary-repo--feature-branch/vendor/cache/.git" "$group_dir/stale-repo/.git"
  linked_worktree stale-repo-with-worktree feature-branch

  run bash "$script" my-org/team
  assert_success
  reconcile_output=$output
}

# linked_worktree <repo> <branch>: a primary clone and its worktree, wired as git links them.
linked_worktree() {
  local admin=$group_dir/$1/.git/worktrees/$1--$2
  mkdir -p "$admin" "$group_dir/$1--$2"
  printf 'gitdir: %s\n' "$admin" >"$group_dir/$1--$2/.git"
}

@test "a clone whose project is gone from GitLab is looked up and removed" {
  assert_not_exists "$group_dir/stale-repo"
  run cat "$TEST_GLAB_LOG"
  assert_line "api projects/my-org%2Fteam%2Fstale-repo"
  run printf '%s\n' "$reconcile_output"
  assert_line "Gone from GitLab — removing clone:"
  assert_line "  my-org/team/stale-repo"
}

@test "a gone clone with linked worktrees is kept for manual review, worktree and all" {
  assert_dir_exists "$group_dir/stale-repo-with-worktree"
  assert_dir_exists "$group_dir/stale-repo-with-worktree--feature-branch"
  run cat "$TEST_GLAB_LOG"
  assert_line "api projects/my-org%2Fteam%2Fstale-repo-with-worktree"
  run printf '%s\n' "$reconcile_output"
  assert_line "Skipped (needs manual review):"
  assert_line "  my-org/team/stale-repo-with-worktree (gone, has linked worktrees)"
  refute_line "  my-org/team/stale-repo-with-worktree"
}

@test "a linked worktree is neither looked up nor removed" {
  assert_dir_exists "$group_dir/primary-repo--feature-branch"
  run cat "$TEST_GLAB_LOG"
  assert_line "api projects/my-org%2Fteam%2Fstale-repo"
  refute_line "api projects/my-org%2Fteam%2Fprimary-repo--feature-branch"
}

@test "a repo nested inside a worktree is neither looked up nor removed" {
  assert_dir_exists "$group_dir/primary-repo--feature-branch/vendor/cache"
  run cat "$TEST_GLAB_LOG"
  assert_line "api projects/my-org%2Fteam%2Fstale-repo"
  refute_line --partial "primary-repo--feature-branch%2Fvendor%2Fcache"
}
