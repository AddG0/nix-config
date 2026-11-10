# The ExecCondition deciding whether git-sync rebuilds: exit 0 rebuilds, 1 skips, 255 fails the unit.
# $CURRENT_SYSTEM is a fixture generation; $FLAKE_METADATA is what the fake nix reports for the remote; $STATE_DIRECTORY holds the last-built record.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR XDG_CONFIG_HOME=$BATS_TEST_TMPDIR GIT_CONFIG_NOSYSTEM=1
  export STATE_DIRECTORY=$BATS_TEST_TMPDIR/state
  mkdir -p "$STATE_DIRECTORY"
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

# A git remote at $remote whose commit $next follows $running, with the fake flake locked to $next.
remote_moved_past_running() {
  remote=$BATS_TEST_TMPDIR/remote
  git init -q "$remote"
  git -C "$remote" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m running
  running=$(git -C "$remote" rev-parse HEAD)
  git -C "$remote" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m next
  next=$(git -C "$remote" rev-parse HEAD)
  export FLAKE_METADATA="{\"locked\":{\"narHash\":\"sha256-new\",\"rev\":\"$next\",\"type\":\"git\",\"url\":\"file://$remote\"}}"
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

@test "skips when the remote is unchanged since the last rebuild" {
  echo sha256-new >"$STATE_DIRECTORY/last-built-narhash"
  generation_built_from ""
  run "$checkNewer"
  assert_failure 1
  assert_output --partial "Remote flake unchanged since last rebuild (sha256-new); skipping."
}

@test "fails the unit, rather than skipping, when the remote cannot be read" {
  NIX_METADATA_EXIT=1 run "$checkNewer"
  assert_failure 255
}

@test "waits for the network before asking nix for the remote" {
  generation_built_from "$rev"
  export NIX_LOG=$BATS_TEST_TMPDIR/calls PING_LOG=$BATS_TEST_TMPDIR/calls PING_FAILURES=1
  run "$checkNewer"
  assert_equal "$(cut -d' ' -f1 "$NIX_LOG" | paste -sd' ')" "ping ping flake"
  assert_output --partial "Network connectivity confirmed (reached github.com)"
}

@test "fails the unit, rather than skipping, when the network never comes up" {
  export NIX_LOG=$BATS_TEST_TMPDIR/nix.log PING_LOG=$BATS_TEST_TMPDIR/ping.log PING_FAILURES=1
  run "$checkNewerTryingNetworkOnce"
  assert_failure 255
  assert_output --partial "Network connectivity timeout"
  assert [ ! -e "$NIX_LOG" ]
}

@test "rebuilds when a git remote's history moves past the running commit" {
  remote_moved_past_running
  generation_built_from "$running"
  run "$checkNewer"
  assert_success
  assert_output --partial "Remote flake changed ($next) and contains running $running; proceeding with rebuild."
}

@test "fails the unit when git cannot fetch the remote's source to compare histories" {
  export FLAKE_METADATA="{\"locked\":{\"narHash\":\"sha256-new\",\"rev\":\"$rev\",\"type\":\"tarball\",\"url\":\"https://example.invalid/r.tar.gz\"}}"
  generation_built_from fedcba9876543210fedcba9876543210fedcba98
  run "$checkNewer"
  assert_failure 255
  assert_output --partial "Cannot fetch $rev"
}

@test "fetches a GitHub remote's history from github.com to compare" {
  remote_moved_past_running
  git config --global url."file://$remote".insteadOf https://github.com/o/r.git
  export FLAKE_METADATA="{\"locked\":{\"narHash\":\"sha256-new\",\"rev\":\"$next\",\"type\":\"github\",\"owner\":\"o\",\"repo\":\"r\"}}"
  generation_built_from "$running"
  run "$checkNewer"
  assert_success
  assert_output --partial "Remote flake changed ($next) and contains running $running; proceeding with rebuild."
}

@test "skips a hand deploy from a commit missing from the remote's history" {
  remote_moved_past_running
  unpushed_repo=$BATS_TEST_TMPDIR/unpushed
  git init -q "$unpushed_repo"
  git -C "$unpushed_repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m unpushed
  unpushed=$(git -C "$unpushed_repo" rev-parse HEAD)
  generation_built_from "$unpushed"
  run "$checkNewer"
  assert_failure 1
  assert_output --partial "Running $unpushed is not in the remote's history"
}

@test "replaces uncommitted work on an older commit once the remote moves past it" {
  remote_moved_past_running
  generation_built_from "$running-dirty"
  run "$checkNewer"
  assert_success
  assert_output --partial "contains running $running-dirty; proceeding with rebuild."
}
