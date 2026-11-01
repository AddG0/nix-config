# The reserved-file guard a skill's resourcesRoot passes through after it is
# copied, run on a directory as $out.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

@test "a resourcesRoot containing SKILL.md is rejected, naming the tool and skill" {
  mkdir -p "$BATS_TEST_TMPDIR/reserved"
  touch "$BATS_TEST_TMPDIR/reserved/SKILL.md"
  run "$guard" "$BATS_TEST_TMPDIR/reserved"
  assert_failure
  assert_output --partial "codex skill 'demo' resourcesRoot must not contain SKILL.md"
}

@test "a resourcesRoot without reserved files is accepted" {
  mkdir -p "$BATS_TEST_TMPDIR/clean"
  touch "$BATS_TEST_TMPDIR/clean/reference.md"
  run "$guard" "$BATS_TEST_TMPDIR/clean"
  assert_success
  assert_output ""
}
