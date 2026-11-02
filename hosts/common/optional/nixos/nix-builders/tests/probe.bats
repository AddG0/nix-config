# The probe rewriting the active builder list: $CONFIGURED_MACHINES is the full list, $ACTIVE_MACHINES what nix offers.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export CONFIGURED_MACHINES=$BATS_TEST_TMPDIR/machines
  export ACTIVE_MACHINES=$BATS_TEST_TMPDIR/active
  printf '%s' "$machines" >"$CONFIGURED_MACHINES"
}

# As systemd starts it: nothing on PATH but what the script brings itself.
probe() {
  env -i PATH=/var/empty CONFIGURED_MACHINES="$CONFIGURED_MACHINES" ACTIVE_MACHINES="$ACTIVE_MACHINES" "$probe"
}

@test "leaves out unreachable builders and reports each one" {
  run probe
  assert_success
  assert_output --partial "builders:"
  assert_output --partial "unreachable"
  assert_equal "$(cat "$ACTIVE_MACHINES")" ""
}

@test "leaves an unchanged list in place when re-probed, and reports nothing" {
  run probe
  assert_success
  before=$(stat -c %i "$ACTIVE_MACHINES")
  run probe
  assert_success
  refute_output --partial "builders:"
  assert_equal "$(stat -c %i "$ACTIVE_MACHINES")" "$before"
}

@test "rewrites the active list when the configured builders change" {
  run probe
  : >"$CONFIGURED_MACHINES"
  printf 'stale\n' >"$ACTIVE_MACHINES"
  run probe
  assert_success
  assert_output "builders:"
  assert_equal "$(cat "$ACTIVE_MACHINES")" ""
}
