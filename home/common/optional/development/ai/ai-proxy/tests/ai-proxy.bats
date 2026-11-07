# The Codex launcher over a stub ai-proxy that is or is not ready, and the REAL
# ai-proxy.sh `ready` over a stub curl: it logs its arguments to $CURL_LOG and
# prints $CURL_RESULT (default 200) as the HTTP status, or fails when it is "fail"
# or its arguments contain $CURL_FAIL_URL. A global git config shaped like the
# real one marks a repo in the work folder, or with a work remote, as work.

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
  export AI_PROXY_CLAUDE_URL='https://claude-{pool}.example'
  export AI_PROXY_CLAUDE_DEFAULT_POOL=personal
  export AI_PROXY_CLAUDE_POOLS="personal work"
  export AI_PROXY_CLAUDE_ROUTES_FILE=$BATS_TEST_TMPDIR/routes.json
  jq -n --arg tmp "$BATS_TEST_TMPDIR" '{
    "\($tmp)/work": "work",
    "\($tmp)/work/personal": "personal"
  }' >"$AI_PROXY_CLAUDE_ROUTES_FILE"
  export AI_PROXY_SCOPE=test
  token=$XDG_STATE_HOME/ai-proxy/token.json

  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=$BATS_TEST_TMPDIR/gitconfig
  printf '[ai-proxy]\n\tpool = work\n' >"$BATS_TEST_TMPDIR/work.gitconfig"
  {
    printf '[includeIf "gitdir:%s/work/**"]\n\tpath = %s/work.gitconfig\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR"
    printf '[includeIf "hasconfig:remote.*.url:git@gitlab-work:acme/**"]\n\tpath = %s/work.gitconfig\n' "$BATS_TEST_TMPDIR"
  } >"$GIT_CONFIG_GLOBAL"

  mkdir -p "$BATS_TEST_TMPDIR/personal/folder" "$BATS_TEST_TMPDIR/work/folder" "$BATS_TEST_TMPDIR/work/personal/folder" "$BATS_TEST_TMPDIR/work-other/folder"
}

# Makes a git repo at $1 whose origin is $2, and enters it.
clone() {
  git init -q "$1"
  git -C "$1" remote add origin "$2"
  cd "$1"
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

@test "a claude session in a folder outside any repo and route is sent to the default host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/personal/folder"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
  run cat "$CURL_LOG"
  assert_line --regexp 'claude-cli/ai-proxy-ready .* https://claude-personal\.example/v1/models$'
}

@test "a claude session in a folder outside any repo, under a route root, is sent to that route's host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/folder"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
  run cat "$CURL_LOG"
  assert_line --regexp 'claude-cli/ai-proxy-ready .* https://claude-work\.example/v1/models$'
  refute_line --partial claude-personal.example
}

@test "the deepest route root holding a folder outside any repo wins" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/personal/folder"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
}

@test "a folder entered through a symlink is routed by the directory it resolves to" {
  logged_in
  ln -s "$BATS_TEST_TMPDIR/work/folder" "$BATS_TEST_TMPDIR/link"
  cd "$BATS_TEST_TMPDIR/link"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
}

@test "a folder that only shares a route root's name prefix uses the default host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work-other/folder"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
}

@test "a repo with a work remote is sent to the work host outside every route" {
  logged_in
  clone "$BATS_TEST_TMPDIR/personal/repo" git@gitlab-work:acme/group/repo.git
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
  run cat "$CURL_LOG"
  refute_line --partial claude-personal.example
}

@test "a repo in the work folder is sent to the work host whatever its remote" {
  logged_in
  clone "$BATS_TEST_TMPDIR/work/repo" https://github.com/me/repo.git
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
}

@test "a repo elsewhere with a personal remote is sent to the default host" {
  logged_in
  clone "$BATS_TEST_TMPDIR/personal/repo" https://github.com/me/repo.git
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
}

@test "inside a repo git config decides, not the deeper folder route around it" {
  logged_in
  clone "$BATS_TEST_TMPDIR/work/personal/repo" https://github.com/me/repo.git
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
}

@test "a repo git config leaves without a pool uses the default host, even under a work route" {
  logged_in
  clone "$BATS_TEST_TMPDIR/work/repo" https://github.com/me/repo.git
  printf '' >"$GIT_CONFIG_GLOBAL"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
}

@test "an empty ai-proxy.pool is a broken config: ready exits 2, naming the key and the repo" {
  logged_in
  clone "$BATS_TEST_TMPDIR/personal/repo" git@gitlab-work:acme/repo.git
  git config ai-proxy.pool ""
  run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 2
  assert_output ""
  assert_equal "$stderr" "ai-proxy: git config ai-proxy.pool is empty in $(realpath "$BATS_TEST_TMPDIR/personal/repo")/.git, but must be one of: personal work"
  assert_not_exists "$CURL_LOG"
}

@test "an ai-proxy.pool key with no value is a broken config: ready exits 2" {
  logged_in
  clone "$BATS_TEST_TMPDIR/personal/repo" https://github.com/me/repo.git
  printf '[ai-proxy]\n\tpool\n' >>.git/config
  run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 2
  assert_output ""
  assert_regex "$stderr" "^ai-proxy: git config ai-proxy.pool is empty in "
}

@test "a session in a repo's .git folder is sent by the repo's git config, not the folder route around it" {
  logged_in
  clone "$BATS_TEST_TMPDIR/work/personal/repo" https://github.com/me/repo.git
  cd .git
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
}

@test "a session in a bare repo with a work remote is sent to the work host" {
  logged_in
  git init -q --bare "$BATS_TEST_TMPDIR/personal/repo.git"
  git -C "$BATS_TEST_TMPDIR/personal/repo.git" remote add origin git@gitlab-work:acme/repo.git
  cd "$BATS_TEST_TMPDIR/personal/repo.git"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
}

@test "a session in a subfolder of a repo is sent by the repo's git config" {
  logged_in
  clone "$BATS_TEST_TMPDIR/personal/repo" git@gitlab-work:acme/repo.git
  mkdir src
  cd src
  run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-work.example"}}'
}

@test "an ai-proxy.pool that names no pool is a broken config: ready exits 2, naming the key, the value and the repo" {
  logged_in
  clone "$BATS_TEST_TMPDIR/personal/repo" https://github.com/me/repo.git
  git config ai-proxy.pool junk
  run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 2
  assert_output ""
  assert_equal "$stderr" "ai-proxy: git config ai-proxy.pool is \"junk\" in $(realpath "$BATS_TEST_TMPDIR/personal/repo")/.git, but must be one of: personal work"
  assert_not_exists "$CURL_LOG"
}

@test "a repo whose git config cannot be read is a broken config: ready exits 2, naming the directory, rather than routing it by folder" {
  logged_in
  clone "$BATS_TEST_TMPDIR/work/repo" git@gitlab-work:acme/repo.git
  printf '[broken\n' >>.git/config
  run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 2
  assert_output ""
  assert_regex "$stderr" "^ai-proxy: cannot tell whether $BATS_TEST_TMPDIR/work/repo is in a git repo, so cannot tell its Claude pool: fatal: bad config"
  assert_not_exists "$CURL_LOG"
}

@test "status names git config as what chose the host in a marked repo" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  clone "$BATS_TEST_TMPDIR/personal/repo" git@gitlab-work:acme/repo.git
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line '  claude   here: https://claude-work.example, pool work from git config (ai-proxy.pool)'
}

@test "status says a repo git config leaves without a pool takes the default, naming its origin" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  clone "$BATS_TEST_TMPDIR/personal/repo" https://github.com/me/repo.git
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line '  claude   here: https://claude-personal.example, pool personal by default, as git config sets no ai-proxy.pool (origin https://github.com/me/repo.git)'
}

@test "status says a repo with no origin that git config leaves without a pool takes the default" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  git init -q "$BATS_TEST_TMPDIR/personal/repo"
  cd "$BATS_TEST_TMPDIR/personal/repo"
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line '  claude   here: https://claude-personal.example, pool personal by default, as git config sets no ai-proxy.pool (no origin)'
}

@test "status says a folder outside any repo and route takes the default" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  cd "$BATS_TEST_TMPDIR/personal/folder"
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line '  claude   here: https://claude-personal.example, pool personal by default, outside any repo and folder route'
}

@test "status names the folder route that chose the host outside a repo" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  cd "$BATS_TEST_TMPDIR/work/folder"
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_line "  claude   here: https://claude-work.example, pool work from folder route $(realpath "$BATS_TEST_TMPDIR/work")"
}

@test "status checks every claude pool's host once" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  run --separate-stderr bash "$aiProxy" status
  assert_success
  assert_equal "$(grep -c 'claude-personal.example accepts' <<<"$output")" 1
  assert_equal "$(grep -c 'claude-work.example accepts' <<<"$output")" 1
}

@test "status fails when a claude pool's host is unreachable" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  CURL_FAIL_URL=claude-work.example run --separate-stderr bash "$aiProxy" status
  assert_equal "$status" 1
  assert_line '  proxy    https://claude-personal.example accepts it'
  assert_line --partial 'https://claude-work.example is unreachable'
}

@test "a session on the proxy is tagged with its directory's pool" {
  cd "$BATS_TEST_TMPDIR/work/folder"
  CLAUDE_SESSION_SETTINGS=applied run --separate-stderr bash "$aiProxy" attributes claude
  assert_success
  assert_output 'ai_proxy.pool=work,ai_proxy.context=work'
}

@test "a session off the proxy is tagged direct, with its directory's pool and its login's email domain" {
  export CLAUDE_CONFIG_DIR=$BATS_TEST_TMPDIR/profile
  mkdir -p "$CLAUDE_CONFIG_DIR"
  printf '%s' '{"oauthAccount":{"emailAddress":"me@gmail.example"}}' >"$CLAUDE_CONFIG_DIR/.claude.json"
  clone "$BATS_TEST_TMPDIR/personal/repo" git@gitlab-work:acme/repo.git
  CLAUDE_SESSION_SETTINGS=skipped run --separate-stderr bash "$aiProxy" attributes claude
  assert_success
  assert_output 'ai_proxy.pool=direct,ai_proxy.context=work,ai_proxy.login_domain=gmail.example'
}

@test "a session off the proxy on a profile with no login is tagged with no login domain" {
  export CLAUDE_CONFIG_DIR=$BATS_TEST_TMPDIR/empty-profile
  cd "$BATS_TEST_TMPDIR/personal/folder"
  CLAUDE_SESSION_SETTINGS=skipped run --separate-stderr bash "$aiProxy" attributes claude
  assert_success
  assert_output 'ai_proxy.pool=direct,ai_proxy.context=personal,ai_proxy.login_domain=none'
}

@test "an unreadable login fails the tag, naming its file" {
  export CLAUDE_CONFIG_DIR=$BATS_TEST_TMPDIR/profile
  mkdir -p "$CLAUDE_CONFIG_DIR"
  printf '%s' '{not json' >"$CLAUDE_CONFIG_DIR/.claude.json"
  CLAUDE_SESSION_SETTINGS=skipped run --separate-stderr bash "$aiProxy" attributes claude
  assert_failure
  assert_output ""
  assert_regex "$stderr" "cannot read the login in $CLAUDE_CONFIG_DIR/.claude.json$"
}

@test "with no routes every claude session outside a repo goes to the default host" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/folder"
  AI_PROXY_CLAUDE_ROUTES_FILE="" run --separate-stderr bash "$aiProxy" ready claude
  assert_success
  assert_output '{"env":{"ANTHROPIC_BASE_URL":"https://claude-personal.example"}}'
  run cat "$CURL_LOG"
  refute_line --partial claude-work.example
}

@test "a claude session is not ready when its routed host does not answer, and never tries another" {
  logged_in
  cd "$BATS_TEST_TMPDIR/work/folder"
  CURL_FAIL_URL=claude-work.example run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 1
  assert_output ""
  run cat "$CURL_LOG"
  assert_line --regexp 'https://claude-work\.example/v1/models$'
  refute_line --partial claude-personal.example
}

@test "a malformed routes file is a broken config: ready outside a repo exits 2 and names the file" {
  logged_in
  cd "$BATS_TEST_TMPDIR/personal/folder"
  printf '%s' '{not json' >"$AI_PROXY_CLAUDE_ROUTES_FILE"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 2
  assert_output ""
  assert_regex "$stderr" "ai-proxy: $AI_PROXY_CLAUDE_ROUTES_FILE is not a JSON object of directory to pool$"
}

@test "a folder route to something that is no pool is a broken config: ready exits 2, naming the file, the root and the pool" {
  logged_in
  cd "$BATS_TEST_TMPDIR/personal/folder"
  jq -n --arg tmp "$BATS_TEST_TMPDIR" '{"\($tmp)/work": "vendor"}' >"$AI_PROXY_CLAUDE_ROUTES_FILE"
  run --separate-stderr bash "$aiProxy" ready claude
  assert_equal "$status" 2
  assert_output ""
  assert_equal "$stderr" "ai-proxy: $AI_PROXY_CLAUDE_ROUTES_FILE routes $BATS_TEST_TMPDIR/work to \"vendor\", but a pool must be one of: personal work"
  assert_not_exists "$CURL_LOG"
}

@test "status inside a repo still reports a folder route to something that is no pool" {
  logged_in
  printf '%s' refresh >"$XDG_STATE_HOME/ai-proxy/refresh_token"
  clone "$BATS_TEST_TMPDIR/personal/repo" git@gitlab-work:acme/repo.git
  jq -n --arg tmp "$BATS_TEST_TMPDIR" '{"\($tmp)/work": "vendor"}' >"$AI_PROXY_CLAUDE_ROUTES_FILE"
  run --separate-stderr bash "$aiProxy" status
  assert_equal "$status" 2
  assert_regex "$stderr" "ai-proxy: $AI_PROXY_CLAUDE_ROUTES_FILE routes $BATS_TEST_TMPDIR/work to \"vendor\""
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
