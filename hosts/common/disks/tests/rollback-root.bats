# The REAL rollback script over a plain directory as the btrfs top level; btrfs subvolumes are directories.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  export PATH=$stubPath:$PATH TZ=UTC
  export TOP=$BATS_TEST_TMPDIR/top
}

# A boot after one long ago, with kept roots on either side of 30 days.
previous_boot() {
  mkdir -p "$TOP/@root/etc" "$TOP/old_roots/ancient" "$TOP/old_roots/recent"
  echo kept >"$TOP/@root/etc/forgotten"
  touch -d "2026-01-02 03:04:05" "$TOP/@root"
  touch -d "40 days ago" "$TOP/old_roots/ancient"
  touch -d "5 days ago" "$TOP/old_roots/recent"
}

# A first boot: no @root yet, and an old_roots last written long ago.
first_boot() {
  mkdir -p "$TOP/old_roots"
  touch -d "40 days ago" "$TOP/old_roots"
}

@test "the previous root is kept under its timestamp, though its boot was over 30 days ago" {
  previous_boot
  run "$rollback"
  assert_success
  run ls "$TOP/old_roots"
  assert_line 2026-01-02_03:04:05
  assert_equal "$(cat "$TOP/old_roots/2026-01-02_03:04:05/etc/forgotten")" kept
}

@test "the previous root is replaced by an empty @root" {
  previous_boot
  run "$rollback"
  assert_success
  assert_dir_exists "$TOP/@root"
  run ls -A "$TOP/@root"
  assert_output ""
}

@test "a kept root older than 30 days is deleted" {
  previous_boot
  run "$rollback"
  assert_success
  assert_not_exists "$TOP/old_roots/ancient"
}

@test "a kept root younger than 30 days is kept" {
  previous_boot
  run "$rollback"
  assert_success
  assert_dir_exists "$TOP/old_roots/recent"
}

@test "old_roots itself is not deleted for being older than 30 days" {
  first_boot
  run "$rollback"
  assert_success
  assert_dir_exists "$TOP/old_roots"
}

@test "@root is created when none existed" {
  first_boot
  run "$rollback"
  assert_success
  assert_dir_exists "$TOP/@root"
}
