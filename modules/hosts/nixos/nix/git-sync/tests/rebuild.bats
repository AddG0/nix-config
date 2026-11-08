# git-sync's run per reboot setting: what it activates, whether it reboots, what it records, and which commits it refuses.
# Fakes log to $NIX_LOG, $NIXOS_REBUILD_LOG, $SYSTEMCTL_LOG and $KUBECTL_LOG; nix links its build to $BUILT_SYSTEM.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR XDG_CONFIG_HOME=$BATS_TEST_TMPDIR GIT_CONFIG_NOSYSTEM=1
  export STATE_DIRECTORY=$BATS_TEST_TMPDIR/state
  mkdir -p "$STATE_DIRECTORY"
  export NIX_LOG=$BATS_TEST_TMPDIR/nix.log NIXOS_REBUILD_LOG=$BATS_TEST_TMPDIR/nixos-rebuild.log
  export SYSTEMCTL_LOG=$BATS_TEST_TMPDIR/systemctl.log KUBECTL_LOG=$BATS_TEST_TMPDIR/kubectl.log
  : >"$NIX_LOG"
  : >"$NIXOS_REBUILD_LOG"
  : >"$SYSTEMCTL_LOG"
  export FLAKE_METADATA='{"url":"github:o/r/0123456789abcdef0123456789abcdef01234567","locked":{"narHash":"sha256-new"}}'

  load "$generations"
  generations_setup
  # Nothing is staged for the next boot: it would boot the running system.
  export CURRENT_SYSTEM=$BOOTED_SYSTEM SYSTEM_PROFILE=$BOOTED_SYSTEM
}

# Makes nixos-rebuild call $1 print $2, as switch-to-configuration's report.
reports() {
  printf '%s\n' "$2" >"$NIXOS_REBUILD_LOG.$1"
}

# The nixos-rebuild action and its first flag, for each activation the run made.
activations() {
  cut -d' ' -f1-2 "$NIXOS_REBUILD_LOG"
}

undone_switch() {
  printf 'switch --store-path\ntest --store-path\nboot --store-path'
}

# The next run's remote check: it skips a remote the run recorded as built, and retries any other.
assert_next_check_skips() {
  run "$checkNewer"
  assert_failure 1
  assert_output --partial "Remote flake unchanged since last rebuild"
}

assert_next_check_retries() {
  run "$checkNewer"
  assert_success
}

# Commits to a fresh $remote, signed with the test key when $1 is "signed", and locks the fake flake to that commit as $rev.
lock_remote_commit() {
  remote=$BATS_TEST_TMPDIR/remote
  git init -q "$remote"
  local signing=()
  if [ "$1" = signed ]; then
    install -m 600 "$signingKey" "$BATS_TEST_TMPDIR/signing-key"
    signing=(-c gpg.format=ssh -c user.signingkey="$BATS_TEST_TMPDIR/signing-key" -c commit.gpgsign=true)
  fi
  git -C "$remote" -c user.name=t -c user.email=t@example.com "${signing[@]}" commit -q --allow-empty -m change
  rev=$(git -C "$remote" rev-parse HEAD)
  export FLAKE_METADATA="{\"url\":\"git+file://$remote?rev=$rev\",\"locked\":{\"narHash\":\"sha256-new\",\"rev\":\"$rev\",\"type\":\"git\",\"url\":\"file://$remote\"}}"
}

# Activation per reboot setting

@test "switches to a userspace-only build and stays up when set to reboot on a kernel change" {
  generation "$BUILT_SYSTEM"
  run "$rebuildOnKernelChange"
  assert_success
  assert_output --partial "Userspace-only update; no reboot needed."
  assert_equal "$(activations)" "switch --store-path"
  assert_equal "$(cat "$SYSTEMCTL_LOG")" ""
}

@test "activates a build with a new kernel at the next boot, then reboots into it when set to reboot on a kernel change" {
  generation "$BUILT_SYSTEM" kernel
  run "$rebuildOnKernelChange"
  assert_success
  assert_output --partial "The kernel differs from the booted system's."
  assert_equal "$(activations)" "boot --store-path"
  assert_equal "$(cat "$SYSTEMCTL_LOG")" "reboot"
}

@test "builds the locked revision and reboots after every rebuild when set to always reboot" {
  generation "$BUILT_SYSTEM"
  run "$rebuildAlways"
  assert_success
  assert_equal "$(grep '^build' "$NIX_LOG" | cut -d' ' -f4)" 'github:o/r/0123456789abcdef0123456789abcdef01234567#nixosConfigurations."t".config.system.build.toplevel'
  assert_equal "$(activations)" "switch --store-path"
  assert_equal "$(cat "$SYSTEMCTL_LOG")" "reboot"
}

@test "drains the Kubernetes node before a reboot it starts" {
  generation "$BUILT_SYSTEM"
  # One log for kubectl and systemctl keeps their calls in order.
  export KUBECTL_LOG=$SYSTEMCTL_LOG
  run "$rebuildAlways"
  assert_success
  assert_equal "$(cut -d' ' -f1 "$SYSTEMCTL_LOG" | paste -sd' ')" "get drain reboot"
}

@test "switches to a userspace-only build and stays up when set to never reboot" {
  generation "$BUILT_SYSTEM"
  run "$rebuildNever"
  assert_success
  assert_equal "$(activations)" "switch --store-path"
  refute_output --partial "WARNING"
  assert_equal "$(cat "$SYSTEMCTL_LOG")" ""
}

@test "leaves a build with new kernel modules for the next boot, warning, and stays up when set to never reboot" {
  generation "$BUILT_SYSTEM" kernel-modules
  run "$rebuildNever"
  assert_success
  assert_equal "$(activations)" "boot --store-path"
  assert_output --partial "WARNING: This update changes the kernel, initrd or kernel modules, so it waits for the next reboot."
  assert_equal "$(cat "$SYSTEMCTL_LOG")" ""
}

# What the next run retries

@test "records the remote it built, so the next check skips it" {
  generation "$BUILT_SYSTEM"
  run "$rebuildOnKernelChange"
  assert_success
  assert_next_check_skips
}

@test "skips the reboot, and leaves the remote for the next run, when the post-rebuild hook fails" {
  generation "$BUILT_SYSTEM"
  POST_REBUILD_FAILS=1 run "$rebuildHooked"
  assert_failure
  assert_equal "$(cat "$SYSTEMCTL_LOG")" ""
  assert_next_check_retries
}

@test "leaves the remote for the next run when the reboot cannot be started" {
  generation "$BUILT_SYSTEM"
  SYSTEMCTL_REBOOT_EXIT=1 run "$rebuildHooked"
  assert_failure
  assert_next_check_retries
}

@test "reboots anyway, with a warning, when the pre-reboot hook fails" {
  generation "$BUILT_SYSTEM"
  PRE_REBOOT_FAILS=1 run "$rebuildHooked"
  assert_success
  assert_output --partial "WARNING: pre-reboot hook failed (exit 1); rebooting anyway."
  assert_equal "$(cat "$SYSTEMCTL_LOG")" "reboot"
}

# Failed builds, failed activations and restores

@test "leaves the host untouched, recording nothing, when the build fails" {
  NIX_BUILD_EXIT=3 run "$rebuildOnKernelChange"
  assert_failure 1
  assert_output --partial "Build failed (exit code 3)"
  assert_equal "$(cat "$NIXOS_REBUILD_LOG")" ""
  assert_equal "$(cat "$SYSTEMCTL_LOG")" ""
  assert_next_check_retries
}

@test "re-activates the running system and keeps the staged next boot when switching to the build fails" {
  generation "$BATS_TEST_TMPDIR/running"
  generation "$BATS_TEST_TMPDIR/staged" kernel
  export CURRENT_SYSTEM=$BATS_TEST_TMPDIR/running SYSTEM_PROFILE=$BATS_TEST_TMPDIR/staged
  generation "$BUILT_SYSTEM"
  NIXOS_REBUILD_EXITS=1 run "$rebuildOnKernelChange"
  assert_failure 1
  assert_output --partial "Activation failed (exit code 1)"
  assert_equal "$(sed -n '2,3p' "$NIXOS_REBUILD_LOG")" "$(printf 'test --store-path %s\nboot --store-path %s' "$(readlink -f "$CURRENT_SYSTEM")" "$(readlink -f "$SYSTEM_PROFILE")")"
  assert_output --partial "Restored the previous system."
  assert_equal "$(cat "$SYSTEMCTL_LOG")" ""
  assert_next_check_retries
}

@test "puts back the system already staged for the next boot when staging a new kernel fails" {
  generation "$BATS_TEST_TMPDIR/staged" initrd
  export SYSTEM_PROFILE=$BATS_TEST_TMPDIR/staged
  generation "$BUILT_SYSTEM" kernel
  NIXOS_REBUILD_EXITS=1 run "$rebuildNever"
  assert_failure 1
  assert_equal "$(activations)" "$(printf 'boot --store-path\nboot --store-path')"
  assert_equal "$(sed -n 2p "$NIXOS_REBUILD_LOG")" "boot --store-path $(readlink -f "$BATS_TEST_TMPDIR/staged")"
  assert_equal "$(cat "$SYSTEMCTL_LOG")" ""
}

@test "says the previous system could not be restored when the restore fails too" {
  generation "$BUILT_SYSTEM"
  NIXOS_REBUILD_EXITS="1 1 1" run "$rebuildOnKernelChange"
  assert_failure 1
  assert_output --partial "ERROR: Could not re-activate"
  assert_output --partial "ERROR: Could not set the next boot back"
  refute_output --partial "Restored the previous system."
}

# Exit 4: activated, but switch-to-configuration reported a problem

@test "keeps a switch that fails only for units already broken before the run" {
  generation "$BUILT_SYSTEM"
  reports 1 "warning: the following units failed: bluetooth.service"
  FAILED_UNITS=bluetooth.service NIXOS_REBUILD_EXITS=4 run "$rebuildOnKernelChange"
  assert_success
  assert_output --partial "WARNING: Activated; the only failed units were already broken before this run."
  assert_equal "$(activations)" "switch --store-path"
  assert_next_check_skips
}

@test "undoes a switch that leaves failing a unit that was healthy before the run" {
  generation "$BUILT_SYSTEM"
  reports 1 "warning: the following units failed: bluetooth.service, k3s.service"
  FAILED_UNITS=bluetooth.service NIXOS_REBUILD_EXITS=4 run "$rebuildOnKernelChange"
  assert_failure 1
  assert_output --partial "Activation failed (exit code 4)"
  assert_equal "$(activations)" "$(undone_switch)"
  assert_next_check_retries
}

@test "undoes a switch that exits 4 for any other cause, even beside a unit already broken before the run" {
  generation "$BUILT_SYSTEM"
  for cause in \
    "Failed to restart k3s.service: timed out" \
    "Unable to list users with logind: access denied" \
    "warning: user activation for t failed" \
    "warning: failed to stat /run/user/1000 for user t; skipping: access denied"; do
    : >"$NIXOS_REBUILD_LOG"
    reports 1 "$(printf '%s\nwarning: the following units failed: bluetooth.service' "$cause")"
    FAILED_UNITS=bluetooth.service NIXOS_REBUILD_EXITS=4 run "$rebuildOnKernelChange"
    assert_failure 1
    assert_equal "$(activations)" "$(undone_switch)"
  done
}

@test "undoes a switch that exits 4 without saying why" {
  generation "$BUILT_SYSTEM"
  FAILED_UNITS=bluetooth.service NIXOS_REBUILD_EXITS=4 run "$rebuildOnKernelChange"
  assert_failure 1
  assert_equal "$(activations)" "$(undone_switch)"
}

@test "counts a service restarting after a failed exit as already broken" {
  generation "$BUILT_SYSTEM"
  reports 1 "warning: the following units failed: worker.service"
  RESTARTING_UNITS=worker.service EXEC_MAIN_STATUS=1 NIXOS_REBUILD_EXITS=4 run "$rebuildOnKernelChange"
  assert_success
  assert_equal "$(activations)" "switch --store-path"
}

@test "undoes a switch that breaks a service caught restarting after a clean exit" {
  generation "$BUILT_SYSTEM"
  reports 1 "warning: the following units failed: worker.service"
  RESTARTING_UNITS=worker.service EXEC_MAIN_STATUS=0 NIXOS_REBUILD_EXITS=4 run "$rebuildOnKernelChange"
  assert_failure 1
  assert_equal "$(activations)" "$(undone_switch)"
}

@test "counts the restore as done when it fails only for units already broken before the run" {
  generation "$BUILT_SYSTEM"
  reports 1 "warning: the following units failed: bluetooth.service, k3s.service"
  reports 2 "warning: the following units failed: bluetooth.service"
  FAILED_UNITS=bluetooth.service NIXOS_REBUILD_EXITS="4 4" run "$rebuildOnKernelChange"
  assert_failure 1
  assert_output --partial "Restored the previous system."
  refute_output --partial "Could not re-activate"
}

# Signatures

@test "activates a commit an allowed key signed" {
  lock_remote_commit signed
  generation "$BUILT_SYSTEM"
  run "$rebuildSigned"
  assert_success
  assert_output --partial "Verified signature on $rev."
  assert_equal "$(activations)" "switch --store-path"
}

@test "refuses, before building anything, a commit no allowed key signed" {
  lock_remote_commit unsigned
  run "$rebuildSigned"
  assert_failure 1
  assert_output --partial "$rev from file://$remote is not signed by an allowed key. Refusing to rebuild."
  refute grep -q '^build' "$NIX_LOG"
  assert_equal "$(cat "$NIXOS_REBUILD_LOG")" ""
}
