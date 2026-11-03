# The REAL write-for-people-gate hook over hook payloads for one session.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export XDG_RUNTIME_DIR=$BATS_TEST_TMPDIR/run
}

bash_call() {
  jq -nc --arg cmd "$1" '{session_id: "s1", hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $cmd}}'
}

skill_call() {
  jq -nc --arg skill "$1" '{session_id: "s1", hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: $skill}}'
}

skill_loaded() {
  skill_call "$1" | "$gate"
}

assert_denied() {
  run "$gate" < <(bash_call "$1")
  assert_success
  assert_equal "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$output")" deny
}

assert_allowed() {
  run "$gate" < <(bash_call "$1")
  assert_success
  assert_output ""
}

@test "creating a jira ticket before write-for-people loads is denied" {
  assert_denied '/home/u/skills/jira/jira-cli create "Title" "Body" -a me'
}

@test "a jira comment, an MR note and a gh PR before write-for-people loads are denied" {
  assert_denied 'jira-cli comment add ENG26-1 "text"'
  assert_denied 'glab mr note create 12 -R group/repo -m "text"'
  assert_denied 'gh pr create --title t --body b'
}

@test "writing a review, comment or note through gh api or glab api before write-for-people loads is denied" {
  assert_denied 'gh api repos/o/r/pulls/3/reviews --input review.json'
  assert_denied 'gh api -X POST repos/o/r/pulls/3/comments -f body=text'
  assert_denied 'glab api --method POST projects/1/merge_requests/2/notes -f body=text'
}

@test "reading comments or discussions through gh api or glab api is allowed without write-for-people" {
  assert_allowed 'gh api repos/o/r/pulls/3/comments'
  assert_allowed 'glab api projects/1/merge_requests/2/discussions --paginate'
}

@test "rewording a jira description before write-for-people loads is denied" {
  assert_denied 'jira-cli update ENG26-1 --description "new text"'
}

@test "reading tickets and MRs is allowed without write-for-people" {
  assert_allowed 'jira-cli get ENG26-1'
  assert_allowed 'jira-cli search -a me'
  assert_allowed 'glab mr note list 12 -R group/repo -F json'
  assert_allowed 'gh pr view 3'
}

@test "updating jira fields that hold no prose is allowed without write-for-people" {
  assert_allowed 'jira-cli update ENG26-1 --story-points 2'
}

@test "posting is allowed once write-for-people has loaded in the session" {
  skill_loaded write-for-people
  assert_allowed 'jira-cli create "Title" "Body"'
}

@test "loading a different skill does not open the gate" {
  skill_loaded jira
  assert_denied 'jira-cli create "Title" "Body"'
}

@test "compaction closes the gate again, since it drops the loaded skill body" {
  skill_loaded write-for-people
  jq -nc '{session_id: "s1", hook_event_name: "SessionStart", source: "compact"}' | "$gate"
  assert_denied 'jira-cli create "Title" "Body"'
}

@test "write-for-people loaded in another session does not open this one" {
  jq -nc '{session_id: "other", hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: "write-for-people"}}' | "$gate"
  assert_denied 'jira-cli create "Title" "Body"'
}

@test "loading a skill that posts text before write-for-people tells Claude to load it before drafting" {
  for skill in jira gitlab-mr investigate review-pr; do
    run "$gate" < <(skill_call "$skill")
    assert_success
    assert_equal "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")" "This skill posts text another person reads. Load the write-for-people skill before drafting it."
  done
}

@test "loading jira after write-for-people adds nothing" {
  skill_loaded write-for-people
  run "$gate" < <(skill_call jira)
  assert_success
  assert_output ""
}

@test "loading an unrelated skill adds nothing" {
  run "$gate" < <(skill_call nix-build)
  assert_success
  assert_output ""
}
