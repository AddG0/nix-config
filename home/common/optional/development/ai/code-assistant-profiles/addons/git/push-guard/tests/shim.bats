# The git shim ahead of real git on claude's PATH: it blocks push, directly or
# through any alias, unless ALLOW_GIT_PUSH=1, and passes everything else on.

bats_require_minimum_version 1.5.0

setup_file() {
  export HOME=$BATS_FILE_TMPDIR/home
  mkdir -p "$HOME" "$BATS_FILE_TMPDIR/shim"
  ln -s "$gitShim" "$BATS_FILE_TMPDIR/shim/git"
  export PATH=$BATS_FILE_TMPDIR/shim:$PATH
  git config --global user.name t
  git config --global user.email t@example.invalid
  git config --global init.defaultBranch main
}

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  cd "$BATS_TEST_TMPDIR" || return
  git init -q --bare remote.git
  git init -q work
  echo one >work/file
  git -C work add file
  git -C work commit -qm one
  git -C work remote add origin "$BATS_TEST_TMPDIR/remote.git"
}

assert_push_blocked() {
  run "$@"
  assert_failure
  assert_output --partial 'git push blocked: rerun as ALLOW_GIT_PUSH=1 git '
  # An unreadable remote would make the next check pass unchecked.
  run git -C "$BATS_TEST_TMPDIR/remote.git" rev-parse --git-dir
  assert_success
  run git -C "$BATS_TEST_TMPDIR/remote.git" rev-parse -q --verify refs/heads/main
  assert_failure
}

# What a claude started inside an older session's shell also has on PATH: that
# session's shim, which looked git up on PATH.
older_shim() {
  mkdir -p older-shim
  printf '#!%s\n' "$BASH" >older-shim/git
  cat >>older-shim/git <<'SH'
self=${0%/*}
exec "$(PATH=$(printf '%s' "$PATH" | tr : '\n' | grep -vxF "$self" | paste -sd:) command -v git)" "$@"
SH
  chmod +x older-shim/git
}

@test "push is blocked with ALLOW_GIT_PUSH unset" {
  cd work || return
  assert_push_blocked env -u ALLOW_GIT_PUSH git push -q origin HEAD:main
}

@test "push is blocked with ALLOW_GIT_PUSH empty" {
  cd work || return
  assert_push_blocked env ALLOW_GIT_PUSH= git push -q origin HEAD:main
}

@test "push is blocked with ALLOW_GIT_PUSH=0" {
  cd work || return
  assert_push_blocked env ALLOW_GIT_PUSH=0 git push -q origin HEAD:main
}

@test "push is blocked with ALLOW_GIT_PUSH=false" {
  cd work || return
  assert_push_blocked env ALLOW_GIT_PUSH=false git push -q origin HEAD:main
}

@test "push is blocked behind git -C <dir>" {
  assert_push_blocked git -C work push -q origin HEAD:main
}

@test "push is blocked behind git -c <key>=<value>" {
  cd work || return
  assert_push_blocked git -c push.default=current push -q origin HEAD:main
}

@test "push is blocked behind git --attr-source <tree>" {
  assert_push_blocked git -C work --attr-source HEAD push -q origin HEAD:main
}

@test "push is blocked behind git --config-env <name>=<envvar>" {
  assert_push_blocked git --config-env core.pager=HOME -C work push -q origin HEAD:main
}

@test "push is blocked behind --namespace, --git-dir and --work-tree" {
  assert_push_blocked git --namespace n --git-dir work/.git --work-tree work push -q origin HEAD:main
}

@test "push is blocked through a command-line alias" {
  assert_push_blocked git -C work -c alias.p=push p -q origin HEAD:main
}

@test "push is blocked through a chain of aliases ending in push" {
  assert_push_blocked git -C work -c alias.a=b -c alias.b='push -q' a origin HEAD:main
}

@test "push is blocked through a shell alias running git push" {
  assert_push_blocked git -C work -c 'alias.sp=!git push' sp -q origin HEAD:main
}

@test "push is blocked through an alias from the repository's config" {
  git -C work config alias.up push
  assert_push_blocked git -C work up -q origin HEAD:main
}

@test "an alias for a command other than push reaches real git" {
  echo two >work/file
  run git -C work -c alias.st=status st --porcelain
  assert_success
  assert_output " M file"
}

@test "an alias shadowing a git command runs the command, as git does" {
  echo two >work/file
  run git -C work -c alias.status=push status --porcelain
  assert_success
  assert_output " M file"
}

@test "git stash push reaches real git and cleans the worktree" {
  echo two >work/file
  run git -C work stash push -q
  assert_success
  assert_equal "$(git -C work stash list | wc -l)" 1
  run git -C work status --porcelain
  assert_success
  assert_output ""
}

@test "an approved push lands on the remote" {
  run env ALLOW_GIT_PUSH=1 git -C work push -q origin HEAD:main
  assert_success
  run git -C "$BATS_TEST_TMPDIR/remote.git" rev-parse -q --verify refs/heads/main
  assert_success
}

# A failure with status 124 means the two shims looped until the timeout.
@test "an approved push lands with the current shim ahead of an older session's" {
  older_shim
  run env ALLOW_GIT_PUSH=1 PATH="$BATS_FILE_TMPDIR/shim:$PWD/older-shim:$PATH" timeout 10 git -C work push -q origin HEAD:main 3>&-
  assert_success
  run git -C "$BATS_TEST_TMPDIR/remote.git" rev-parse -q --verify refs/heads/main
  assert_success
}

@test "an approved push lands with an older session's shim ahead of the current one" {
  older_shim
  run env ALLOW_GIT_PUSH=1 PATH="$PWD/older-shim:$BATS_FILE_TMPDIR/shim:$PATH" timeout 10 git -C work push -q origin HEAD:main 3>&-
  assert_success
  run git -C "$BATS_TEST_TMPDIR/remote.git" rev-parse -q --verify refs/heads/main
  assert_success
}
