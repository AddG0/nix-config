.checks["config.load"]
| (if .status != "ok" then "config.load: \(.status): \(.summary)" else empty end),
  (.details | to_entries[] | select((.key | startswith("startup warning")) and .value != "0") | "\(.key): \(.value)")
