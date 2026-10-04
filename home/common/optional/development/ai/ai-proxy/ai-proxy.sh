# Signs in to the OIDC issuer for ai-proxy with a device code (RFC 8628) and hands out the JWT its gateway accepts.

umask 077
state="${XDG_STATE_HOME:-$HOME/.local/state}/ai-proxy"
mkdir -p "$state"

body=$(mktemp)
trap 'rm -f "$body"' EXIT

fail() {
  echo "ai-proxy: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ai-proxy [command]

  status   who you are logged in as, and whether $AI_PROXY_URL and $AI_PROXY_CLAUDE_URL accept you (the default)
  login    sign in through $AI_PROXY_ISSUER in a browser
  logout   end the session and forget it on this machine
  token    print an access token (what Codex and Claude Code run)
EOF
}

describe() {
  jq -r '.error_description // .error // "no detail"' "$body" 2>/dev/null || echo "unreadable response"
}

# Endpoints come from the issuer's discovery document, so nothing here depends on which OIDC server it is.
endpoint() {
  local url="$AI_PROXY_ISSUER/.well-known/openid-configuration" value
  value=$(curl -fsS --max-time 20 "$url" | jq -er --arg key "$1" '.[$key] // empty') || fail "cannot read $1 from $url"
  echo "$value"
}

# POSTs to an endpoint, leaving the response in $body and printing the HTTP status.
post() {
  local url=$1
  shift
  curl -sS --max-time 20 -o "$body" -w '%{http_code}' "$url" -d "client_id=$AI_PROXY_CLIENT_ID" "$@" ||
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

status() {
  local access minutes failed=0

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
  # The Claude host admits only a claude-cli/ User-Agent (gitops ADR-0010), answering anything else as it would a bad token.
  check_proxy "$AI_PROXY_CLAUDE_URL" "$access" "claude-cli/ai-proxy-status" || failed=1
  return "$failed"
}

# Codex (auth.command) and Claude Code (apiKeyHelper) read stdout as the credential, so nothing else goes there.
token() {
  local token_endpoint code

  # Every Codex run and Claude Code session calls this: one refresh at a time keeps a rotated refresh token from being spent twice.
  exec 9>"$state/lock"
  flock 9

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
help | -h | --help) usage ;;
*)
  usage >&2
  exit 1
  ;;
esac
