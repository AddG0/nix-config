# The directoryEnv runner and wrap, built from one rule that sets
# DIRECTORY_ENV_TEST=applied under $tree/scoped.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

var_in() {
  cd "$1" || return
  run "$runner" printenv DIRECTORY_ENV_TEST
}

@test "the rule's env is exported at the named path" {
  var_in "$tree/scoped"
  assert_success
  assert_output applied
}

@test "the rule's env is exported below the named path" {
  var_in "$tree/scoped/deep"
  assert_success
  assert_output applied
}

@test "a sibling sharing the path as a prefix does not get the rule's env" {
  var_in "$tree/scoped-sibling"
  # printenv exits 1 for an unset name, not merely an empty one.
  assert_failure 1
  assert_output ""
}

@test "outside the named path the rule's env stays unset" {
  var_in "$tree"
  assert_failure 1
  assert_output ""
}

@test "the runner forwards argv to the command it execs" {
  run "$runner" printf '%s|%s' one two
  assert_success
  assert_output "one|two"
}

@test "wrap keeps the wrapped program's name" {
  assert_equal "$(basename "$wrappedEnv")" env
}

@test "a wrapped program sees the rule's env" {
  cd "$tree/scoped"
  run "$wrappedEnv"
  assert_success
  assert_line DIRECTORY_ENV_TEST=applied
}
