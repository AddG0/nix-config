# agent-run against stub agents that print BINARY=<name>, CWD=<dir>, then their
# arguments one per line, so the generated invocation is observed, not inferred.

bats_require_minimum_version 1.5.0

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  PATH=$stubBin:$PATH
}

# The index in $lines of the first line equal to $1, or -1.
line_index() {
  local i
  for i in "${!lines[@]}"; do
    if [[ ${lines[i]} == "$1" ]]; then
      echo "$i"
      return
    fi
  done
  echo -1
}

@test "--list-agents lists every enabled agent" {
  run "$agentRun" --list-agents
  assert_success
  assert_output "$(printf 'claude-code\ncodex\nopencode')"
}

@test "--list-agents does not offer a disabled target" {
  run "$claudeOnlyAgentRun" --list-agents
  assert_success
  assert_output claude-code
}

@test "selecting a disabled agent fails as unknown" {
  run "$claudeOnlyAgentRun" --agent codex
  assert_failure
  assert_output --partial 'unknown agent: codex'
}

@test "with no --agent the configured default runs" {
  run "$agentRun" --prompt hello
  assert_success
  assert_line BINARY=claude
}

@test "claude gets its auto-approve flag and value" {
  run "$agentRun" --prompt hello
  assert_success
  assert_line -- --permission-mode
  assert_line bypassPermissions
}

@test "claude gets the prompt right after a -- separator" {
  run "$agentRun" --prompt hello
  assert_success
  sep=$(line_index --)
  ((sep >= 0)) || fail "no -- separator in: $output"
  assert_equal "${lines[sep + 1]}" hello
}

@test "opencode gets its auto-approve flag" {
  run "$agentRun" --agent opencode --prompt hello
  assert_success
  assert_line -- --auto
}

@test "opencode gets the prompt as the value of --prompt, with no bare separator" {
  run "$agentRun" --agent opencode --prompt hello
  assert_success
  flag=$(line_index --prompt)
  ((flag >= 0)) || fail "no --prompt flag in: $output"
  assert_equal "${lines[flag + 1]}" hello
  refute_line -- --
}

@test "codex gets its auto-approve flag" {
  run "$agentRun" --agent codex --prompt hello
  assert_success
  assert_line -- --dangerously-bypass-approvals-and-sandbox
}

@test "arguments after -- reach the agent ahead of the prompt separator" {
  run "$agentRun" --prompt hi -- --model opus
  assert_success
  model=$(line_index --model)
  sep=$(line_index --)
  ((model >= 0 && sep >= 0 && model < sep)) || fail "--model (line $model) must precede -- (line $sep) in: $output"
}

@test "--skill names the skill in the prompt" {
  run "$agentRun" --skill diagnose-crash
  assert_success
  assert_output --partial 'Use the diagnose-crash skill'
}

@test "--help documents every flag" {
  run "$agentRun" --help
  assert_success
  for flag in --agent --prompt --skill --cwd --list-agents --list-skills; do
    assert_output --partial -- "$flag"
  done
}

@test "a prompt and a skill together keep both" {
  run "$agentRun" --prompt 'why did it die' --skill diagnose-crash
  assert_success
  assert_output --partial 'why did it die'
  assert_output --partial 'Use the diagnose-crash skill'
}

@test "an unknown skill fails and lists the available ones" {
  run "$agentRun" --skill nope
  assert_failure
  assert_output --partial 'unknown skill: nope'
  assert_output --partial 'diagnose-crash nix-build'
}

@test "a profile with no skills still rejects --skill" {
  run "$noSkillsAgentRun" --skill nope
  assert_failure
  assert_output --partial 'defines none'
}

@test "with no default configured and no --agent it fails rather than guess" {
  run "$noDefaultAgentRun" --prompt x
  assert_failure
  assert_output --partial 'no agent selected and no default configured'
}

@test "--agent works with no default configured" {
  run "$noDefaultAgentRun" --agent codex --prompt x
  assert_success
  assert_line BINARY=codex
}

@test "an unknown agent fails" {
  run "$agentRun" --agent gemini
  assert_failure
  assert_output --partial 'unknown agent: gemini'
}

@test "a flag with no value fails" {
  run "$agentRun" --prompt
  assert_failure
  assert_output --partial -- '--prompt requires a value'
}

@test "--cwd rejects a path that is not a directory" {
  run "$agentRun" --cwd /nonexistent-dir --prompt x
  assert_failure
  assert_output --partial -- '--cwd is not a directory'
}

@test "--cwd runs the agent in a real directory" {
  mkdir -p "$BATS_TEST_TMPDIR/workdir"
  run "$agentRun" --cwd "$BATS_TEST_TMPDIR/workdir" --prompt x
  assert_success
  assert_line "CWD=$BATS_TEST_TMPDIR/workdir"
}

@test "a missing agent binary fails naming it" {
  run -127 env PATH=/nonexistent "$agentRun" --prompt x
  assert_output --partial 'is not on PATH'
}

# Every word agent-run passes to an installed tool must still be in its --help.
help_lists_flags() {
  local target=$1 check binary version words word
  check=$(jq -c --arg t "$target" '.[] | select(.target == $t)' <<<"$helpChecks")
  binary=$(jq -r .binary <<<"$check")
  version=$(jq -r .version <<<"$check")
  mapfile -t words < <(jq -r '.words[]' <<<"$check")
  run env HOME="$BATS_TEST_TMPDIR/home" "$binary" --help
  assert_success
  for word in "${words[@]}"; do
    grep -qwF -- "$word" <<<"$output" ||
      fail "agent-run passes $word to ${binary##*/}, but $version --help no longer lists it:
$output"
  done
}

while read -r target; do
  bats_test_function --description "the installed $target still accepts every flag agent-run passes it" -- help_lists_flags "$target"
done < <(jq -r '.[].target' <<<"$helpChecks")
