# git-sync's reboot check: telling a build only a reboot activates (kernel, initrd, modules) from one switch can apply.
# Fixture generations from $generations share one kernel, initrd and module set unless a case swaps one.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  load "$generations"
  generations_setup
}

@test "leaves a userspace-only build to switch" {
  generation "$BUILT_SYSTEM"
  run "$needsReboot" "$BUILT_SYSTEM"
  assert_failure 1
}

@test "needs a reboot for a build with a new kernel" {
  generation "$BUILT_SYSTEM" kernel
  run "$needsReboot" "$BUILT_SYSTEM"
  assert_success
  assert_output "The kernel differs from the booted system's."
}

@test "needs a reboot for a build with a new initrd" {
  generation "$BUILT_SYSTEM" initrd
  run "$needsReboot" "$BUILT_SYSTEM"
  assert_success
  assert_output "The initrd differs from the booted system's."
}

@test "needs a reboot for a build with new kernel modules" {
  generation "$BUILT_SYSTEM" kernel-modules
  run "$needsReboot" "$BUILT_SYSTEM"
  assert_success
  assert_output "The kernel-modules differs from the booted system's."
}

@test "refuses to guess without a system to compare" {
  run "$needsReboot"
  assert_failure 2
  assert_output --partial "usage:"
}
