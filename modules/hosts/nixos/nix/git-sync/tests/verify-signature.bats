# git-sync's signature gate: a locked commit is rebuilt only when a key in the allowed-signers file signed it.
# Fixtures: $remote, a repo whose commits each case signs with $allowed_key or $other_key, or leaves unsigned.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR XDG_CONFIG_HOME=$BATS_TEST_TMPDIR GIT_CONFIG_NOSYSTEM=1
  allowed_key=$BATS_TEST_TMPDIR/allowed
  other_key=$BATS_TEST_TMPDIR/other
  ssh-keygen -q -t ed25519 -N "" -C allowed -f "$allowed_key"
  ssh-keygen -q -t ed25519 -N "" -C other -f "$other_key"
  allowed_signers=$BATS_TEST_TMPDIR/allowed-signers
  echo "git-sync namespaces=\"git\" $(cat "$allowed_key.pub")" >"$allowed_signers"

  remote=$BATS_TEST_TMPDIR/remote
  git init -q "$remote"
}

# Commits to $remote signed with private key $1, or unsigned when $1 is empty, and prints the commit.
commit_signed_with() {
  local signing=()
  [ -z "$1" ] || signing=(-c gpg.format=ssh -c user.signingkey="$1" -c commit.gpgsign=true)
  git -C "$remote" -c user.name=t -c user.email=t@example.com "${signing[@]}" commit -q --allow-empty -m change
  git -C "$remote" rev-parse HEAD
}

@test "accepts a commit signed by an allowed key" {
  rev=$(commit_signed_with "$allowed_key")
  run "$verifySignature" "$allowed_signers" "file://$remote" "$rev"
  assert_success
  assert_output --partial "Verified signature on $rev."
}

@test "refuses an unsigned commit" {
  rev=$(commit_signed_with "")
  run "$verifySignature" "$allowed_signers" "file://$remote" "$rev"
  assert_failure 1
  assert_output --partial "$rev from file://$remote is not signed by an allowed key."
}

@test "refuses a commit signed by a key that is not allowed" {
  rev=$(commit_signed_with "$other_key")
  run "$verifySignature" "$allowed_signers" "file://$remote" "$rev"
  assert_failure 1
  assert_output --partial "is not signed by an allowed key."
}

@test "refuses a locked flake that has no git revision" {
  run "$verifySignature" "$allowed_signers" "file://$remote" ""
  assert_failure 1
  assert_output --partial "Cannot verify a signature without a git remote and revision"
}

@test "refuses a commit it cannot fetch" {
  run "$verifySignature" "$allowed_signers" "file://$BATS_TEST_TMPDIR/missing" 0123456789abcdef0123456789abcdef01234567
  assert_failure 1
  assert_output --partial "Cannot fetch 0123456789abcdef0123456789abcdef01234567"
}

@test "refuses to guess without all three arguments" {
  run "$verifySignature" "$allowed_signers" "file://$remote"
  assert_failure 2
  assert_output --partial "usage:"
}
