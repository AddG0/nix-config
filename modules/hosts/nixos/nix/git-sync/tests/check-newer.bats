# The ExecCondition deciding whether git-sync rebuilds: exit 0 rebuilds, 1 skips, 255 fails the unit.
# $CURRENT_SYSTEM is a fixture generation; $FLAKE_METADATA is what the fake nix reports for the remote.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  rev=0123456789abcdef0123456789abcdef01234567
  export CURRENT_SYSTEM=$BATS_TEST_TMPDIR/system
  mkdir -p "$CURRENT_SYSTEM/sw/bin"
  export FLAKE_METADATA="{\"locked\":{\"narHash\":\"sha256-new\",\"rev\":\"$rev\",\"type\":\"github\",\"owner\":\"o\",\"repo\":\"r\"}}"
}

# A nixos-version reporting the given revision, or exiting 1 like one built without it.
generation_built_from() {
  if [ -n "$1" ]; then
    printf '#!/bin/sh\n[ "$1" = --configuration-revision ] && echo %s\n' "$1" >"$CURRENT_SYSTEM/sw/bin/nixos-version"
  else
    printf '#!/bin/sh\nexit 1\n' >"$CURRENT_SYSTEM/sw/bin/nixos-version"
  fi
  chmod +x "$CURRENT_SYSTEM/sw/bin/nixos-version"
}

@test "skips when the running generation was built from the remote's current commit" {
  generation_built_from "$rev"
  run "$checkNewer"
  assert_failure 1
  assert_output --partial "Running $rev, built from the remote's current commit; skipping."
}

@test "treats a generation built from uncommitted work on the remote's commit as that commit" {
  generation_built_from "$rev-dirty"
  run "$checkNewer"
  assert_failure 1
  assert_output --partial "Running $rev-dirty, built from the remote's current commit"
}

@test "rebuilds when the running generation was built without a revision" {
  generation_built_from ""
  run "$checkNewer"
  assert_success
  assert_output --partial "contains running unknown; proceeding with rebuild."
}

@test "rebuilds when the running generation has no nixos-version" {
  rm -r "$CURRENT_SYSTEM/sw"
  run "$checkNewer"
  assert_success
  assert_output --partial "contains running unknown"
}
