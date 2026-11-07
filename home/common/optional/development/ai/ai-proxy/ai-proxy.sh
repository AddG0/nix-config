# shellcheck shell=bash
# Signs in to the OIDC issuer for ai-proxy with a device code (RFC 8628) and hands out the JWT its gateway accepts.

umask 077
state="${XDG_STATE_HOME:-$HOME/.local/state}/ai-proxy"
mkdir -p "$state"

body=$(mktemp)
git_errors=$(mktemp)
trap 'rm -f "$body" "$git_errors"' EXIT

fail() {
  echo "ai-proxy: $*" >&2
  exit 1
}

# Exit 2 tells the claude wrapper to abort the session, where 1 only means the proxy is not ready.
broken_config() {
  echo "ai-proxy: $*" >&2
  exit 2
}

usage() {
  cat <<EOF
Usage: ai-proxy [command]

  status   who you are logged in as, and whether $AI_PROXY_URL and the Claude hosts accept you (the default)
  login    sign in through $AI_PROXY_ISSUER in a browser
  logout   end the session and forget it on this machine
  token    print an access token (what Codex and Claude Code run)
  ready    exit successfully when the named proxy is ready (general or claude); for claude, print
           the settings that send the session to the host of this repo's or folder's pool, and
           exit 2 rather than 1 when the config that picks that pool is broken
  attributes claude
           print the OpenTelemetry resource attributes naming a Claude Code session's pool
EOF
}

describe() {
  jq -r '.error_description // .error // "no detail"' "$body" 2>/dev/null || echo "unreadable response"
}

# Endpoints come from the issuer's discovery document, so nothing here depends on which OIDC server it is.
endpoint() {
  local url="$AI_PROXY_ISSUER/.well-known/openid-configuration" value
  value=$(curl -fsS --max-time "${AI_PROXY_TIMEOUT:-20}" "$url" | jq -er --arg key "$1" '.[$key] // empty') || fail "cannot read $1 from $url"
  echo "$value"
}

# POSTs to an endpoint, leaving the response in $body and printing the HTTP status.
post() {
  local url=$1
  shift
  curl -sS --max-time "${AI_PROXY_TIMEOUT:-20}" -o "$body" -w '%{http_code}' "$url" -d "client_id=$AI_PROXY_CLIENT_ID" "$@" ||
    fail "cannot reach $url"
}

save_tokens() {
  # The issuer may rotate the refresh token on every refresh; keep the old one if a response lacks it.
  if jq -e '.refresh_token' "$body" >/dev/null; then
    jq -j .refresh_token "$body" >"$state/refresh_token.new"
    mv "$state/refresh_token.new" "$state/refresh_token"
  fi
  jq --argjson now "$(date +%s)" '{access_token, expires_at: ($now + .expires_in)}' "$body" >"$state/token.json.new"
  mv "$state/token.json.new" "$state/token.json"
}

# userinfo rather than the id_token, whose claims depend on how the IdP is configured.
save_identity() {
  local url
  url=$(endpoint userinfo_endpoint)
  if ! curl -fsS --max-time 20 -H "Authorization: Bearer $(jq -r .access_token "$state/token.json")" "$url" |
    jq --argjson now "$(date +%s)" '{name: (.name // .preferred_username), email, since: $now}' >"$state/identity.json.new"; then
    rm -f "$state/identity.json.new"
    echo "ai-proxy: signed in, but $url did not say who you are" >&2
    return 0
  fi
  mv "$state/identity.json.new" "$state/identity.json"
}

who() {
  if [[ -s "$state/identity.json" ]]; then
    jq -r '((.name // "") + (if .email then " <\(.email)>" else "" end)) as $who | if $who == "" then "an unnamed account" else $who end' "$state/identity.json"
  else
    echo "an unnamed account"
  fi
}

open_browser() {
  if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] && command -v xdg-open >/dev/null; then
    xdg-open "$1" >/dev/null 2>&1 &
  elif [[ "$(uname)" == Darwin ]]; then
    open "$1"
  fi
}

login() {
  local device_endpoint token_endpoint code device_code interval deadline url

  # In a subshell: token exits the script when the session can't be refreshed, and that only means signing in again.
  if [[ -s "$state/refresh_token" ]] && (token >/dev/null 2>&1); then
    echo "Already logged in as $(who). Run ai-proxy logout first to switch accounts."
    return 0
  fi

  device_endpoint=$(endpoint device_authorization_endpoint)
  token_endpoint=$(endpoint token_endpoint)

  code=$(post "$device_endpoint" --data-urlencode "scope=$AI_PROXY_SCOPE")
  [[ $code == 200 ]] || fail "$device_endpoint refused the login (HTTP $code: $(describe))"

  device_code=$(jq -r .device_code "$body")
  interval=$(jq -r '.interval // 5' "$body")
  deadline=$(($(date +%s) + $(jq -r '.expires_in // 300' "$body")))
  url=$(jq -r '.verification_uri_complete // .verification_uri' "$body")
  echo "Open $url"
  echo "and confirm the code $(jq -r .user_code "$body")"
  open_browser "$url"
  echo "Waiting for you to approve it in the browser..."

  while true; do
    sleep "$interval"
    (($(date +%s) < deadline)) || fail "the code expired before it was approved; run ai-proxy login again"

    code=$(post "$token_endpoint" \
      -d grant_type=urn:ietf:params:oauth:grant-type:device_code \
      --data-urlencode "device_code=$device_code")
    if [[ $code == 200 ]]; then
      exec 9>"$state/lock"
      flock 9
      save_tokens
      save_identity
      echo "Logged in as $(who)."
      return 0
    fi

    case "$(jq -r '.error // empty' "$body" 2>/dev/null)" in
    authorization_pending) ;;
    slow_down) interval=$((interval + 5)) ;;
    access_denied) fail "the login was denied in the browser" ;;
    expired_token) fail "the code expired before it was approved; run ai-proxy login again" ;;
    *) fail "the login failed (HTTP $code: $(describe))" ;;
    esac
  done
}

logout() {
  local account url code=""

  exec 9>"$state/lock"
  flock 9
  if [[ ! -s "$state/refresh_token" ]]; then
    echo "Not logged in."
    return 0
  fi

  account=$(who)
  # Revoked while the token is still on disk to send; forgotten here whether or not the issuer agrees.
  if url=$(endpoint revocation_endpoint); then
    code=$(post "$url" --data-urlencode "token@$state/refresh_token" -d token_type_hint=refresh_token) || code=""
  fi
  rm -f "$state/refresh_token" "$state/token.json" "$state/identity.json"
  [[ $code == 200 ]] || fail "logged $account out of this machine, but the issuer did not end the session${code:+ (HTTP $code: $(describe))}"
  echo "Logged out $account."
}

# Prints one `proxy` line for a host and fails unless it accepts the token.
check_proxy() {
  local url=$1 access=$2 agent=$3 code

  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -A "$agent" -H "Authorization: Bearer $access" "$url/v1/models") || code=000
  case "$code" in
  200) echo "  proxy    $url accepts it" ;;
  000)
    echo "  proxy    $url is unreachable; it answers only on the LAN and Tailscale"
    return 1
    ;;
  *)
    echo "  proxy    $url refused it (HTTP $code)"
    return 1
    ;;
  esac
}

# A Claude pool's host: its account's instance (gitops ADR-0040).
claude_url() {
  printf '%s\n' "${AI_PROXY_CLAUDE_URL//\{pool\}/$1}"
}

is_pool() {
  local pool
  for pool in $AI_PROXY_CLAUDE_POOLS; do
    [[ $1 == "$pool" ]] && return 0
  done
  return 1
}

# Prints one route per line: its root directory, a tab, its Claude pool.
claude_routes() {
  local routes root pool
  [[ -n ${AI_PROXY_CLAUDE_ROUTES_FILE:-} ]] || return 0
  routes=$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$AI_PROXY_CLAUDE_ROUTES_FILE") ||
    broken_config "$AI_PROXY_CLAUDE_ROUTES_FILE is not a JSON object of directory to pool"
  while IFS=$'\t' read -r root pool; do
    [[ -n $root ]] || continue
    is_pool "$pool" || broken_config "$AI_PROXY_CLAUDE_ROUTES_FILE routes $root to \"$pool\", but a pool must be one of: $AI_PROXY_CLAUDE_POOLS"
  done <<<"$routes"
  printf '%s\n' "$routes"
}

# Prints the git dir of the repo holding this directory, whether a work tree, its .git folder or a bare repo; nothing outside any repo.
git_dir() {
  local dir status=0
  # The C locale pins the message matched below.
  dir=$(LC_ALL=C git -C "$PWD" rev-parse --absolute-git-dir 2>"$git_errors") || status=$?
  if ((status == 0)); then
    printf '%s\n' "$dir"
  elif [[ $(<"$git_errors") != "fatal: not a git repository (or any"* ]]; then
    broken_config "cannot tell whether $PWD is in a git repo, so cannot tell its Claude pool: $(<"$git_errors")"
  fi
}

# Prints the pool git config names for the repo at git dir $1, a tab, and the rule that chose it.
repo_pool() {
  local repo=$1 pool status=0 origin origin_status=0
  pool=$(git -C "$PWD" config --get ai-proxy.pool 2>"$git_errors") || status=$?
  case $status in
  0) ;;
  1)
    # Names the origin, so a work remote spelled in a way no include matches shows here.
    origin="origin $(git -C "$PWD" config --get remote.origin.url 2>"$git_errors")" || origin_status=$?
    case $origin_status in
    0) ;;
    1) origin="no origin" ;;
    *) broken_config "cannot read the origin of $repo (git config exited $origin_status): $(<"$git_errors")" ;;
    esac
    printf '%s\tby default, as git config sets no ai-proxy.pool (%s)\n' "$AI_PROXY_CLAUDE_DEFAULT_POOL" "$origin"
    return 0
    ;;
  *) broken_config "cannot read git config ai-proxy.pool in $repo (git config exited $status), so cannot tell its Claude pool: $(<"$git_errors")" ;;
  esac
  [[ -n $pool ]] || broken_config "git config ai-proxy.pool is empty in $repo, but must be one of: $AI_PROXY_CLAUDE_POOLS"
  is_pool "$pool" || broken_config "git config ai-proxy.pool is \"$pool\" in $repo, but must be one of: $AI_PROXY_CLAUDE_POOLS"
  printf '%s\tfrom git config (ai-proxy.pool)\n' "$pool"
}

# Prints the pool of the deepest folder route holding this directory, a tab, and that route; the default under none.
folder_pool() {
  local dir routes root route_pool matched_root="" pool=$AI_PROXY_CLAUDE_DEFAULT_POOL
  dir=$(realpath -m -- "$PWD")
  routes=$(claude_routes) || return
  while IFS=$'\t' read -r root route_pool; do
    [[ -n $root ]] || continue
    root=$(realpath -m -- "$root")
    if [[ ($dir == "$root" || $dir == "$root"/*) && ${#root} -gt ${#matched_root} ]]; then
      matched_root=$root
      pool=$route_pool
    fi
  done <<<"$routes"
  if [[ -n $matched_root ]]; then
    printf '%s\tfrom folder route %s\n' "$pool" "$matched_root"
  else
    printf '%s\tby default, outside any repo and folder route\n' "$pool"
  fi
}

# Prints this directory's Claude pool, a tab, and the rule that chose it: inside a git repo its git config, outside one the folder routes (ADR 0023).
claude_route() {
  local repo
  repo=$(git_dir) || return
  if [[ -n $repo ]]; then
    repo_pool "$repo"
  else
    folder_pool
  fi
}

proxy_accepts() {
  local url=$1 agent=$2 access=$3 code
  code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 2 -A "$agent" -H "Authorization: Bearer $access" "$url/v1/models") || return 1
  [[ $code == 200 ]]
}

# The claude wrapper merges what this prints over its settings, so it prints nothing but that JSON.
ready() {
  local access route pool host

  case "${1:-}" in
  general | claude) ;;
  *) fail "ready expects general or claude" ;;
  esac

  access=$(AI_PROXY_TIMEOUT=2 token 2 2>/dev/null) || return 1
  if [[ $1 == general ]]; then
    proxy_accepts "$AI_PROXY_URL" ai-proxy-ready "$access"
    return
  fi

  route=$(claude_route) || return
  IFS=$'\t' read -r pool _ <<<"$route"
  host=$(claude_url "$pool")
  proxy_accepts "$host" claude-cli/ai-proxy-ready "$access" || return 1
  jq -cn --arg url "$host" '{env: {ANTHROPIC_BASE_URL: $url}}'
}

# Tags a Claude Code session: the pool it reached, or direct when the wrapper applied no proxy settings, and its directory's pool.
attributes() {
  local route pool login domain=none
  [[ ${1:-} == claude ]] || fail "attributes expects claude"
  route=$(claude_route) || return
  IFS=$'\t' read -r pool _ <<<"$route"
  if [[ ${CLAUDE_SESSION_SETTINGS:-} == applied ]]; then
    printf 'ai_proxy.pool=%s,ai_proxy.context=%s\n' "$pool" "$pool"
    return 0
  fi
  # Off the proxy the session runs on its profile's own login; its email's domain says whose.
  login=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json
  if [[ -e $login ]]; then
    domain=$(jq -r '.oauthAccount.emailAddress // "" | split("@")[1] // "none"' "$login") || fail "cannot read the login in $login"
  fi
  printf 'ai_proxy.pool=direct,ai_proxy.context=%s,ai_proxy.login_domain=%s\n' "$pool" "$domain"
}

status() {
  local access minutes pool route why failed=0

  if [[ ! -s "$state/refresh_token" ]]; then
    echo "Not logged in. Run: ai-proxy login"
    return 1
  fi
  access=$(token)
  minutes=$((($(jq -r .expires_at "$state/token.json") - $(date +%s)) / 60))

  echo "Logged in as $(who)"
  if [[ -s "$state/identity.json" ]]; then
    echo "  since    $(date -d "@$(jq -r .since "$state/identity.json")" '+%Y-%m-%d %H:%M')"
  fi
  echo "  issuer   $AI_PROXY_ISSUER"
  echo "  token    good for $minutes more minutes, then renewed on its own"

  check_proxy "$AI_PROXY_URL" "$access" "ai-proxy-status" || failed=1
  # The Claude hosts admit only a claude-cli/ User-Agent (gitops ADR-0010), answering anything else as they would a bad token.
  for pool in $AI_PROXY_CLAUDE_POOLS; do
    check_proxy "$(claude_url "$pool")" "$access" "claude-cli/ai-proxy-status" || failed=1
  done
  # Inside a repo no session reads the routes, so status is where a broken routes file shows.
  claude_routes >/dev/null || return
  route=$(claude_route) || return
  IFS=$'\t' read -r pool why <<<"$route"
  echo "  claude   here: $(claude_url "$pool"), pool $pool $why"
  return "$failed"
}

# Codex (auth.command) and Claude Code (apiKeyHelper) read stdout as the credential, so nothing else goes there.
token() {
  local lock_wait=${1:-} token_endpoint code

  # Every Codex run and Claude Code session calls this: one refresh at a time keeps a rotated refresh token from being spent twice.
  exec 9>"$state/lock"
  if [[ -n $lock_wait ]]; then
    flock -w "$lock_wait" 9 || return 1
  else
    flock 9
  fi

  # Six minutes, as Claude Code and Codex each reuse a token for five before asking again.
  if [[ -s "$state/token.json" ]] && jq -e --argjson now "$(date +%s)" '.expires_at - 360 > $now' "$state/token.json" >/dev/null; then
    jq -j .access_token "$state/token.json"
    return 0
  fi

  [[ -s "$state/refresh_token" ]] || fail "not logged in; run ai-proxy login"

  token_endpoint=$(endpoint token_endpoint)
  code=$(post "$token_endpoint" -d grant_type=refresh_token --data-urlencode "refresh_token@$state/refresh_token")
  [[ $code == 200 ]] || fail "$token_endpoint refused the refresh (HTTP $code: $(describe)); run ai-proxy login"

  save_tokens
  jq -j .access_token "$body"
}

case "${1:-status}" in
status) status ;;
login) login ;;
logout) logout ;;
token) token ;;
ready) ready "${2:-}" ;;
attributes) attributes "${2:-}" ;;
help | -h | --help) usage ;;
*)
  usage >&2
  exit 1
  ;;
esac
