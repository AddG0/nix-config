# The claude wrapper against a claude stub that prints its arguments one per
# line: proxy settings added only when the probe succeeds, a caller's
# --settings merged into them, and the wrapper's PATH.

bats_require_minimum_version 1.5.0

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR/home
  mkdir -p "$HOME/.config/claude-code/profiles/default"
  cd "$BATS_TEST_TMPDIR" || return
}

@test "a reachable proxy adds its settings to the session" {
  run "$reachableWrapper"
  assert_success
  assert_line -- --settings
  assert_line '{"apiKeyHelper":"proxy-token"}'
}

@test "a caller's inline --settings is merged into the proxy settings, not passed twice" {
  run --separate-stderr "$reachableWrapper" --settings '{"showThinkingSummaries":true}' -p hi
  assert_success
  assert_equal "$(grep -cx -- --settings <<<"$output")" 1
  assert_line '{"apiKeyHelper":"proxy-token","showThinkingSummaries":true}'
  assert_line -- -p
}

@test "a caller's --settings=file is merged into the proxy settings" {
  echo '{"model":"opus"}' >caller.json
  run --separate-stderr "$reachableWrapper" --settings=caller.json
  assert_success
  assert_line '{"apiKeyHelper":"proxy-token","model":"opus"}'
}

@test "an unreadable caller --settings aborts instead of dropping it" {
  run "$reachableWrapper" --settings missing.json
  assert_failure
  assert_output --partial 'cannot merge --settings missing.json'
}

@test "an unreachable proxy passes the caller's --settings through unchanged" {
  run --separate-stderr "$unreachableWrapper" --settings '{"showThinkingSummaries":true}'
  assert_success
  assert_line '{"showThinkingSummaries":true}'
}

@test "an unreachable proxy adds no session settings" {
  run --separate-stderr "$unreachableWrapper"
  assert_success
  assert_output ""
}

@test "extraPath tools come before PATH, shadowing a same-named tool" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\n' >"$BATS_TEST_TMPDIR/bin/shadowed-tool"
  chmod +x "$BATS_TEST_TMPDIR/bin/shadowed-tool"
  PATH=$BATS_TEST_TMPDIR/bin:$PATH
  run --separate-stderr "$pathWrapper"
  assert_success
  assert_output "$shadowedTool"
}

@test "--version skips the proxy probe" {
  # The probe sleeps 6s, so only a skipped probe beats the timeout.
  run --separate-stderr timeout 4s "$slowWrapper" --version 3>&-
  assert_success
  assert_line -- --version
}
