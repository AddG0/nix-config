# The Codex launcher over a stub ai-proxy that is or is not ready, and the REAL
# ai-proxy.sh `ready` over a stub curl: it logs its arguments to $CURL_LOG and
# prints $CURL_RESULT (default 200) as the HTTP status, or fails when it is "fail".

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
  export AI_PROXY_CLAUDE_URL=https://claude.example
  export AI_PROXY_SCOPE=test
  token=$XDG_STATE_HOME/ai-proxy/token.json
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

@test "a logged-out proxy is not ready and is never probed" {
  run bash "$aiProxy" ready general
  assert_equal "$status" 1
  assert_output ""
  assert_not_exists "$CURL_LOG"
}
