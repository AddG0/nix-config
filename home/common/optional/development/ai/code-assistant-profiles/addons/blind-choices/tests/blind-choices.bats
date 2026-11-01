# The REAL hide-pick and reveal-pick hooks over a two-question AskUserQuestion
# whose recommended options are "Hook" and "Everywhere".

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  export XDG_RUNTIME_DIR=$BATS_TEST_TMPDIR/run
  sealed=$XDG_RUNTIME_DIR/claude-blind-choices
}

hidden() {
  run "$hide" <"$question"
  assert_success
}

@test "a question with a recommendation is put to the user, not auto-answered" {
  hidden
  assert_equal "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" ask
}

@test "no option is left marked as recommended" {
  hidden
  run jq -e '[.hookSpecificOutput.updatedInput.questions[].options[].label] | any(test("Recommended"))' <<<"$output"
  # 1 is jq -e's "false"; any other failure is jq erroring.
  assert_equal "$status" 1
  assert_output false
}

@test "every option stays in its own question" {
  hidden
  assert_equal "$(jq -c '[.hookSpecificOutput.updatedInput.questions[] | [.options[].label] | sort]' <<<"$output")" \
    '[["Both","Hook","Prompt"],["Everywhere","Popups"]]'
}

@test "an option keeps its own description when shuffled" {
  hidden
  assert_equal "$(jq -c '.hookSpecificOutput.updatedInput.questions[0].options[] | select(.label == "Hook") | .description' <<<"$output")" '"a"'
}

@test "the user is shown every question's sealed pick after answering" {
  hidden
  run "$reveal" <<<'{"tool_use_id":"toolu_1"}'
  assert_success
  assert_equal "$(jq -r '.systemMessage' <<<"$output")" \
    "Claude's pick (sealed before you answered): Approach: Hook; Scope: Everywhere"
}

@test "a sealed pick is revealed only once" {
  hidden
  "$reveal" <<<'{"tool_use_id":"toolu_1"}' >/dev/null
  run "$reveal" <<<'{"tool_use_id":"toolu_1"}'
  assert_success
  assert_output ""
  assert_not_exists "$sealed/toolu_1.json"
}

@test "questions without a recommendation are left untouched and nothing is sealed" {
  run "$hide" < <(jq '.tool_use_id = "toolu_2"
    | .tool_input.questions[0].options[0].label = "Hook"
    | .tool_input.questions[1].options[1].label = "Everywhere"' "$question")
  assert_success
  assert_output ""
  assert_not_exists "$sealed/toolu_2.json"
}

@test "a missing tool_use_id fails open without sealing" {
  run "$hide" < <(jq 'del(.tool_use_id)' "$question")
  assert_failure
  assert_not_exists "$sealed/null.json"
}
