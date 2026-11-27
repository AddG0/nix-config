# The root helper on a fixture of 8 CPUs, V-Cache on cores 0,4 and 1,5, and a resctrl tree; the fakes from ./script.nix log every call to $CALLS.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export CALLS=$BATS_TEST_TMPDIR/calls CPU_ROOT=$BATS_TEST_TMPDIR/cpu RESCTRL_ROOT=$BATS_TEST_TMPDIR/resctrl
  RESCTRL_GROUP=$(id -gn)
  export RESCTRL_GROUP
  : >"$CALLS"
  mkdir -p "$CPU_ROOT/cpu0/cache/index3" "$RESCTRL_ROOT/info/L3"
  echo 0-7 >"$CPU_ROOT/online"
  echo 0 >"$CPU_ROOT/cpu0/cache/index3/id"
  echo ffff >"$RESCTRL_ROOT/info/L3/cbm_mask"
  echo "L3:0=ffff;1=ffff" >"$RESCTRL_ROOT/schemata"
  # The kernel creates a group's files on mkdir; a plain directory cannot, so they exist up front.
  mkdir -p "$RESCTRL_ROOT/game"
  : >"$RESCTRL_ROOT/game/tasks"
}

assert_calls() {
  run cat "$CALLS"
  assert_output "$1"
}

@test "split moves system services off the game's cores and gives the game three quarters of the V-Cache" {
  run "$isolate" split 0,4

  assert_success
  assert_calls "systemctl set-property --runtime system.slice AllowedCPUs=1-3,5-7
systemctl set-property --runtime init.scope AllowedCPUs=1-3,5-7"
  run cat "$RESCTRL_ROOT/game/schemata" "$RESCTRL_ROOT/schemata"
  assert_output "L3:0=fff0
L3:0=f"
}

@test "split lets the user's group add threads to the game's cache group" {
  run "$isolate" split 0,4

  assert_success
  [ "$(stat -c %G "$RESCTRL_ROOT/game/tasks")" = "$RESCTRL_GROUP" ]
  [ -n "$(find "$RESCTRL_ROOT/game/tasks" -perm -g+w)" ]
}

@test "split mounts resctrl when it is not mounted yet" {
  export MOUNTED_EXIT=1

  run "$isolate" split 0,4

  assert_success
  run grep -c "^mount -t resctrl resctrl $RESCTRL_ROOT" "$CALLS"
  assert_output 1
}

@test "split still moves system services on a CPU that cannot partition its L3" {
  rm -r "$RESCTRL_ROOT/info"

  run "$isolate" split 0,4

  assert_success
  assert_output --partial "cannot partition its L3"
  run grep -c 'system.slice AllowedCPUs=1-3,5-7' "$CALLS"
  assert_output 1
}

@test "refuses game CPUs outside the V-Cache CCD" {
  run "$isolate" split 0-2

  assert_failure 1
  assert_output --partial "not within the V-Cache CPUs"
  assert_calls ""
}

@test "refuses anything but a CPU list" {
  run "$isolate" split '0;reboot'

  assert_failure 2
  assert_calls ""
}

@test "refuses a reversed range, which would expand to no CPU at all" {
  run "$isolate" split 4-0

  assert_failure 2
  assert_calls ""
}

@test "refuses CPU numbers it would take long to expand or that carry leading zeros" {
  run "$isolate" split 0-99999999999
  assert_failure 2

  run "$isolate" split 0-004
  assert_failure 2
  assert_calls ""
}

@test "still moves system services when the L3 has too few ways to split" {
  echo 7 >"$RESCTRL_ROOT/info/L3/cbm_mask"

  run "$isolate" split 0,4

  assert_success
  assert_output --partial "too few ways"
  run cat "$RESCTRL_ROOT/schemata"
  assert_output "L3:0=ffff;1=ffff"
}

@test "release gives system services every CPU and every task the whole V-Cache back" {
  "$isolate" split 0,4
  : >"$CALLS"

  run "$isolate" release

  assert_success
  assert_calls "systemctl set-property --runtime system.slice AllowedCPUs=
systemctl set-property --runtime init.scope AllowedCPUs="
  run cat "$RESCTRL_ROOT/schemata"
  assert_output "L3:0=ffff"
}

@test "tries both units and fails when one could not be set" {
  export SYSTEMCTL_FAIL_UNIT=system.slice

  run "$isolate" split 0,4

  assert_failure 1
  assert_output --partial "could not set AllowedCPUs=1-3,5-7 on system.slice"
  run grep -c 'init.scope AllowedCPUs=1-3,5-7' "$CALLS"
  assert_output 1
}

@test "does nothing on a CPU without a cache CCD" {
  export CCD_EXIT=3

  run "$isolate" split 0,4

  assert_success
  assert_calls ""
}

@test "accepts only split with a CPU list and release" {
  run "$isolate" split
  assert_failure 2

  run "$isolate" release extra
  assert_failure 2
  assert_calls ""
}
