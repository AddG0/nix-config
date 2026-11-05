# The Codex launcher over a stub ai-proxy that is or is not ready, and the REAL
# ai-proxy.sh `ready` over a stub curl: it logs its arguments to $CURL_LOG and
# prints $CURL_RESULT (default 200) as the HTTP status, or fails when it is "fail"
# or its arguments contain $CURL_FAIL_URL.

bats_require_minimum_version 1.5.0

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  export PATH=$stubPath:$PATH
  export CURL_LOG=$BATS_TEST_TMPDIR/curl.log
  export XDG_STATE_HOME=$BATS_TEST_TMPDIR/state
  export AI_PROXY_ISSUER=https://auth.example
  export AI_PROXY_CLIENT_ID=test
  export AI_PROXY_URL=https://proxy.example
  export AI_PROXY_CLAUDE_DEFAULT_URL=https://claude-personal.example
  export AI_PROXY_CLAUDE_ROUTES_FILE=$BATS_TEST_TMPDIR/routes.json
  jq -n --arg tmp "$BATS_TEST_TMPDIR" '{
    "\($tmp)/missing": "https://claude-other.example",
    "\($tmp)/work": "https://claude-work.example",
    "\($tmp)/work/repo/personal": "https://claude-personal.example"
  }' >"$AI_PROXY_CLAUDE_ROUTES_FILE"
  export AI_PROXY_SCOPE=test
  token=$XDG_STATE_HOME/ai-proxy/token.json
  mkdir -p "$BATS_TEST_TMPDIR/personal/repo" "$BATS_TEST_TMPDIR/work-other/repo" "$BATS_TEST_TMPDIR/work/repo/personal"
}

logged_in() {
  mkdir -p "$(dirname "$token")"
  printf '%s' '{"access_token":"test","expires_at":4102444800}' >"$token"
}

@test "codex is pointed at the proxy provider when the proxy is ready" {
  run "$readyCodex" exec prompt
  assert_success
  assert_output "$(printf '%s\n' --config 'model_provider="ai-proxy"' exec prompt)"
}

@test "codex keeps its own provider when the proxy is not ready" {
  run "$unreadyCodex" exec prompt
  assert_success
  assert_output "$(printf '%s\n' exec prompt)"
}

@test "a logged-in proxy that accepts the token is ready" {
  logged_in
  run bash "$aiProxy" ready general
  assert_success
  run cat "$CURL_LOG"
  assert_line --regexp 'Authorization: Bearer test https://proxy\.example/v1/models$'
}

@test "an unreachable proxy is not ready" {
  logged_in
  CURL_RESULT=fail run bash "$aiProxy" ready general
  assert_equal "$status" 1
  # ready is a silent probe; any output here is an error, not the reason.
  assert_output ""
  run cat "$CURL_LOG"
  assert_line --regexp 'Authorization: Bearer test https://proxy\.example/v1/models$'
}

@test "a claude session under no route is sent to the default host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/personal/repo"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
  run cat "$CURL_LOG"
  assert_line --regexp 'claude-cli/ai-proxy-ready .* https://claude-personal\.example/v1/models$'
}

@test "a claude session under a route root is sent to that route's host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/repo"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
  run cat "$CURL_LOG"
  assert_line --regexp 'claude-cli/ai-proxy-ready .* https://claude-work\.example/v1/models$'
  refute_line --partial claude-personal.example
}

@test "the deepest route root holding the session wins" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/repo/personal"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
}

@test "a session entered through a symlink is routed by the directory it resolves to" {
  logged_in
  ln -s "$BATS_TEST_TMPDIR/work/repo" "$BATS_TEST_TMPDIR/link"
  cd "$BATS_TEST_TMPDIR/link"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
}

@test "a directory that only shares a route root's name prefix uses the default host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work-other/repo"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
}

@test "with no routes every claude session goes to the default host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/repo"
  AI_PROXY_CLAUDE_ROUTES_FILE="" run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
  run cat "$CURL_LOG"
  refute_line --partial claude-work.example
}

@test "a claude session is not ready when its routed host does not answer, and never tries another" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/repo"
  CURL_FAIL_URL=claude-work.example run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 1
  assert_output ""
  run cat "$CURL_LOG"
  assert_line --regexp 'https://claude-work\.example/v1/models$'
  refute_line --partial claude-personal.example
}

@test "a malformed routes file fails ready and names the file" {
  logged_in
  printf '%s' '{not json' >"$AI_PROXY_CLAUDE_ROUTES_FILE"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_failure
  assert_output ""
  assert_regex "$stderr" "ai-proxy: $AI_PROXY_CLAUDE_ROUTES_FILE is not a JSON object of directory to host$"
}

@test "status checks the default claude host and every routed one once" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line '  proxy    https://claude-other.example accepts it'
  assert_line '  proxy    https://claude-work.example accepts it'
  assert_equal "$(grep -c 'claude-personal.example accepts' <<<"$output")" 1
}

@test "status names the default host under no route" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  cd "$BATS_TEST_TMPDIR/personal/repo"
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line '  claude   here: https://claude-personal.example'
}

@test "status names the routed host and its root" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  cd "$BATS_TEST_TMPDIR/work/repo"
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line "  claude   here: https://claude-work.example, under $(realpath "$BATS_TEST_TMPDIR/work")"
}

@test "status fails when a routed claude host is unreachable" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  CURL_FAIL_URL=claude-work.example run --separate-stderr bash "$aiProxy" status
  assert_equal "$status" 1
  assert_line '  proxy    https://claude-personal.example accepts it'
  assert_line --partial 'https://claude-work.example is unreachable'
}

@test "a logged-out claude session is not ready, prints nothing, and is never probed" {
  run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 1
  assert_output ""
  assert_not_exists "$CURL_LOG"
}

@test "a logged-out proxy is not ready and is never probed" {
  run bash "$aiProxy" ready general
  assert_equal "$status" 1
  assert_output ""
  assert_not_exists "$CURL_LOG"
}
