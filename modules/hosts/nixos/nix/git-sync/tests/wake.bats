# git-sync's RTC wake: setting the alarm, telling an alarm wake from a hand start, and returning the host to the state it woke from.
# Fakes: $WAKEALARM for the RTC, a systemctl logging to $SYSTEMCTL_LOG, fixture generations $BOOTED_SYSTEM and $BUILT_SYSTEM.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export STATE_DIRECTORY=$BATS_TEST_TMPDIR/state
  export WAKEALARM=$BATS_TEST_TMPDIR/wakealarm
  mkdir -p "$STATE_DIRECTORY"
  : >"$WAKEALARM"
  export SYSTEMCTL_LOG=$BATS_TEST_TMPDIR/systemctl.log

  export BOOTED_SYSTEM=$BATS_TEST_TMPDIR/booted BUILT_SYSTEM=$BATS_TEST_TMPDIR/built
  mkdir -p "$BATS_TEST_TMPDIR/store"
  for part in kernel initrd kernel-modules; do
    touch "$BATS_TEST_TMPDIR/store/$part"
  done
  generation "$BOOTED_SYSTEM"
  generation "$BUILT_SYSTEM"
}

# A generation linking the shared fixture kernel, initrd and modules, except $2 which gets its own.
generation() {
  mkdir -p "$1"
  for part in kernel initrd kernel-modules; do
    if [ "$part" = "${2:-}" ]; then
      touch "$1/$part-new"
      ln -s "$1/$part-new" "$1/$part"
    else
      ln -s "$BATS_TEST_TMPDIR/store/$part" "$1/$part"
    fi
  done
}

systemctl_calls() {
  cat "$SYSTEMCTL_LOG"
}

# Asserts $1 (epoch seconds) is the next $schedule in the current TZ.
assert_next_scheduled_run() {
  now=$(date +%s)
  assert [ "$1" -gt "$now" ]
  assert [ "$1" -le $((now + 25 * 3600)) ]
  assert_equal "$(date -d "@$1" +%H:%M)" "$schedule"
}

record_alarm_at() {
  echo "$1" >"$STATE_DIRECTORY/wake-alarm"
}

@test "arms the RTC alarm for the next scheduled run in local time" {
  TZ=America/Chicago run "$armWake"
  assert_success
  TZ=America/Chicago assert_next_scheduled_run "$(cat "$WAKEALARM")"
}

@test "arms the RTC alarm for the next scheduled run when local time is UTC" {
  TZ=UTC run "$armWake"
  assert_success
  TZ=UTC assert_next_scheduled_run "$(cat "$WAKEALARM")"
}

@test "records the armed alarm for the next boot to compare against" {
  run "$armWake"
  assert_success
  assert_equal "$(cat "$STATE_DIRECTORY/wake-alarm")" "$(cat "$WAKEALARM")"
}

@test "treats a boot just after the armed alarm as an alarm wake" {
  record_alarm_at $(($(date +%s) - 60))
  run "$wokenByAlarm"
  assert_success
  assert_output --partial "Woken by the alarm"
}

@test "stays on when booted by hand long after the armed alarm" {
  record_alarm_at $(($(date +%s) - 3600))
  run "$wokenByAlarm"
  assert_failure 1
  assert_output --partial "not by the wake alarm"
}

@test "stays on when booted by hand before the armed alarm" {
  record_alarm_at $(($(date +%s) + 3600))
  run "$wokenByAlarm"
  assert_failure 1
  assert_output --partial "not by the wake alarm"
}

@test "stays on when no alarm was ever armed" {
  run "$wokenByAlarm"
  assert_failure 1
  assert_output --partial "No wake alarm on record"
}

@test "powers off again after the update check when the alarm booted it" {
  run "$syncThenReturnTo" poweroff
  assert_success
  assert_equal "$(systemctl_calls)" "$(printf 'start nix-remote-rebuild.service\npoweroff')"
}

@test "suspends again after the update check when the alarm resumed it" {
  run "$syncThenReturnTo" suspend
  assert_success
  assert_equal "$(systemctl_calls)" "$(printf 'start nix-remote-rebuild.service\nsuspend')"
}

@test "powers off instead of suspending when the rebuild changed the kernel" {
  rm -r "$BUILT_SYSTEM"
  generation "$BUILT_SYSTEM" kernel
  run "$syncThenReturnTo" suspend
  assert_success
  assert_output --partial "changed the kernel"
  assert_equal "$(tail -1 "$SYSTEMCTL_LOG")" "poweroff"
}

@test "powers off instead of suspending when the rebuild changed the kernel modules" {
  rm -r "$BUILT_SYSTEM"
  generation "$BUILT_SYSTEM" kernel-modules
  run "$syncThenReturnTo" suspend
  assert_success
  assert_equal "$(tail -1 "$SYSTEMCTL_LOG")" "poweroff"
}

@test "still returns to suspend when the rebuild fails, naming the failure" {
  SYSTEMCTL_START_EXIT=3 run "$syncThenReturnTo" suspend
  assert_success
  assert_output --partial "nix-remote-rebuild failed (exit 3)"
  assert_equal "$(tail -1 "$SYSTEMCTL_LOG")" "suspend"
}
