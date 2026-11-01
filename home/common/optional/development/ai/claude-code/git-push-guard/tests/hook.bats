# The push guard's PreToolUse hook as rendered into settings.json, and the
# claude wrapper's environment it relies on.

bats_require_minimum_version 1.5.0

setup_file() {
  guard=$(jq -r --arg m "$shellToolsMatcher" '.hooks.PreToolUse[] | select(.matcher == $m) | .hooks[] | select(.type == "command") | .command' "$guardedSettings")
  export guard
}

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  export HOME=$BATS_TEST_TMPDIR/home
  mkdir -p "$HOME/.config/claude-code/profiles/default"
}

decision_of() {
  jq -r '.hookSpecificOutput | "\(.permissionDecision): \(.permissionDecisionReason)"' <<<"$1"
}

@test "settings.json runs the push guard before every shell tool" {
  assert_equal "${guard##*/bin/}" claude-ask-on-push-override
  assert_file_executable "$guard"
}

@test "unreadable hook input asks rather than failing, which Claude would treat as non-blocking" {
  run --separate-stderr "$guard" <<<'not json'
  assert_success
  assert_equal "$(decision_of "$output")" "ask: git-push-guard could not read the hook input"
}

@test "a command setting ALLOW_GIT_PUSH asks" {
  run --separate-stderr "$guard" <<<'{"tool_input": {"command": "ALLOW_GIT_PUSH=1 git push"}}'
  assert_success
  assert_equal "$(decision_of "$output")" "ask: ALLOW_GIT_PUSH (git push)"
}

@test "a command without ALLOW_GIT_PUSH is not asked about" {
  run --separate-stderr "$guard" <<<'{"tool_input": {"command": "git status"}}'
  assert_success
  assert_output ""
}

@test "an ALLOW_GIT_PUSH inherited from the launching shell does not reach claude" {
  run --separate-stderr env ALLOW_GIT_PUSH=1 "$overrideReportingWrapper"
  assert_success
  assert_output unset
}
