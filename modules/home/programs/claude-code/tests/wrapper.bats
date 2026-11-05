# The claude wrapper over a stub printing its arguments: conditional settings, what the check prints, a caller's --settings, and PATH.

bats_require_minimum_version 1.5.0

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export HOME=$BATS_TEST_TMPDIR/home
  mkdir -p "$HOME/.config/claude-code/profiles/default"
  cd "$BATS_TEST_TMPDIR" || return
}

@test "a passing check adds the settings file to the session" {
  run "$passingWrapper"
  assert_success
  assert_line -- --settings
  assert_line '{"apiKeyHelper":"helper-token"}'
}

@test "a caller's inline --settings is merged over the settings file, not passed twice" {
  run --separate-stderr "$passingWrapper" --settings '{"showThinkingSummaries":true}' -p hi
  assert_success
  assert_equal "$(grep -cx -- --settings <<<"$output")" 1
  assert_line '{"apiKeyHelper":"helper-token","showThinkingSummaries":true}'
  assert_line -- -p
}

@test "a caller's --settings=file is merged over the settings file" {
  echo '{"model":"opus"}' >caller.json
  run --separate-stderr "$passingWrapper" --settings=caller.json
  assert_success
  assert_line '{"apiKeyHelper":"helper-token","model":"opus"}'
}

@test "settings the check prints are merged over the settings file" {
  run --separate-stderr "$printingWrapper"
  assert_success
  assert_equal "$(grep -cx -- --settings <<<"$output")" 1
  assert_line '{"apiKeyHelper":"helper-token","env":{"EXAMPLE":"printed"}}'
}

@test "a caller's --settings outranks what the check prints" {
  run --separate-stderr "$printingWrapper" --settings '{"env":{"EXAMPLE":"caller"}}'
  assert_success
  assert_line '{"apiKeyHelper":"helper-token","env":{"EXAMPLE":"caller"}}'
}

@test "check output that is not JSON aborts and names the check" {
  run "$unparsableWrapper"
  assert_failure
  assert_output --partial "settings-check: {not json"
}

@test "an unreadable caller --settings aborts instead of dropping it" {
  run "$passingWrapper" --settings missing.json
  assert_failure
  assert_output --partial 'cannot merge --settings missing.json'
}

@test "a failing check passes the caller's --settings through unchanged" {
  run --separate-stderr "$failingWrapper" --settings '{"showThinkingSummaries":true}'
  assert_success
  assert_line '{"showThinkingSummaries":true}'
}

@test "a failing check adds no session settings" {
  run --separate-stderr "$failingWrapper"
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

@test "--version skips the check" {
  # The check sleeps 6s, so only a skipped check beats the timeout.
  run --separate-stderr timeout 4s "$slowWrapper" --version 3>&-
  assert_success
  assert_line -- --version
}
