# Appended to upstream's main.py at build time, so its methods look this name up at call time.
# ruff: noqa: F821
#
# Upstream's 3s playback poll ignores Spotify's 429, so one host kept the shared app rate-limited for every host.
_RATE_LIMIT_FALLBACK_S = 30
_rate_limited_until = 0.0
_unthrottled_api_request = _spotify_api_request


def _spotify_api_request(endpoint: str, token: str, method: str = "GET", params: dict | None = None, body: dict | None = None) -> dict | None:
    global _rate_limited_until
    url = f"{SPOTIFY_API_BASE}/{endpoint}"
    wait = _rate_limited_until - time.time()
    if wait > 0:
        raise urllib.error.HTTPError(url, 429, f"Rate limited by Spotify for {wait:.0f}s more", {}, None)
    try:
        return _unthrottled_api_request(endpoint, token, method, params, body)
    except urllib.error.HTTPError as e:
        if e.code == 429:
            retry_after = e.headers.get("Retry-After", "") if e.headers else ""
            seconds = int(retry_after) if retry_after.isdigit() else _RATE_LIMIT_FALLBACK_S
            _rate_limited_until = time.time() + seconds
            decky.logger.warning("Spotify rate-limited %s %s; pausing Web API calls for %ds", method, endpoint, seconds)
        raise
