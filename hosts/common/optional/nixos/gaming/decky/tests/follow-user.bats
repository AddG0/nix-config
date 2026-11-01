# decky-follow-user against stubs: id puts greeter below 1000, getent gives
# homeless no home, systemctl appends to $CALLS, systemd-cat to $LOG.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  export HOMES=$BATS_TEST_TMPDIR/homes CALLS=$BATS_TEST_TMPDIR/calls LOG=$BATS_TEST_TMPDIR/log
  boot=$BATS_TEST_TMPDIR/boot.env
  user=$BATS_TEST_TMPDIR/run/user.env
  restart="restart --no-block decky-loader.service"
  mkdir -p "$HOMES/console-user/.local/share/decky" "$HOMES/other-user/.local/share/decky"
  printf 'UNPRIVILEGED_USER=console-user\nUNPRIVILEGED_PATH=%s\n' "$HOMES/console-user/.local/share/decky" >"$boot"
}

teardown() {
  if [ -z "${BATS_TEST_COMPLETED:-}" ] && [ -e "$LOG" ]; then
    echo "# hook log:" >&3
    sed 's/^/#   /' "$LOG" >&3
  fi
}

# The hook's process substitution into systemd-cat would hold bats's fd 3.
login() { PAM_USER=$1 "$followUser" "$boot" "$user" 3>&-; }

env_for() { printf 'UNPRIVILEGED_USER=%s\nUNPRIVILEGED_PATH=%s' "$1" "$HOMES/$1/.local/share/decky"; }

# That process substitution can outlive the hook.
wait_logged() {
  local _
  for _ in $(seq 50); do
    grep -qF "$1" "$LOG" 2>/dev/null && return 0
    sleep 0.1
  done
  fail "not logged: $1"$'\n'"log: $(cat "$LOG" 2>/dev/null)"
}

@test "a system user's login leaves Decky alone" {
  login greeter
  assert_not_exists "$user"
  assert_not_exists "$CALLS"
}

@test "the boot user's login neither rewrites the env it runs with nor restarts Decky" {
  login console-user
  assert_not_exists "$user"
  assert_not_exists "$CALLS"
}

@test "a new user's login points Decky at their data and restarts it" {
  login other-user
  assert_equal "$(cat "$user")" "$(env_for other-user)"
  assert_equal "$(cat "$CALLS")" "$restart"
}

@test "the same user logging in again does not restart Decky" {
  login other-user
  login other-user
  assert_equal "$(cat "$CALLS")" "$restart"
}

@test "switching back to the boot user restarts Decky as that user" {
  login other-user
  login console-user
  assert_equal "$(cat "$user")" "$(env_for console-user)"
  assert_equal "$(cat "$CALLS")" "$restart"$'\n'"$restart"
}

@test "a login whose restart failed reports failure and puts back the env Decky runs with" {
  FAIL_RESTART=1 run login other-user
  assert_failure
  assert_equal "$(cat "$user")" "$(env_for console-user)"
  wait_logged "could not queue a decky-loader restart for other-user"
}

@test "the login after a failed restart retries it" {
  FAIL_RESTART=1 run login other-user
  assert_failure
  login other-user
  assert_equal "$(cat "$user")" "$(env_for other-user)"
  assert_equal "$(cat "$CALLS")" "$restart"
}

@test "a user without a decky data dir does not take Decky" {
  login other-user
  mkdir -p "$HOMES/nodata"
  run login nodata
  assert_failure
  wait_logged "$HOMES/nodata/.local/share/decky is missing"
  assert_equal "$(cat "$user")" "$(env_for other-user)"
  assert_equal "$(cat "$CALLS")" "$restart"
}

@test "a user with no home in passwd does not take Decky" {
  login other-user
  run login homeless
  assert_failure
  wait_logged "no home directory for homeless in passwd"
  assert_equal "$(cat "$user")" "$(env_for other-user)"
  assert_equal "$(cat "$CALLS")" "$restart"
}
