#!/usr/bin/env bash

usage() {
  cat <<'EOF'
Usage:
  no-sleep [--why <reason>] -- <command> [args...]   inhibit while command runs
  no-sleep [--why <reason>] <duration>               inhibit for duration (e.g. 2h, 30m)
  no-sleep [--why <reason>]                          inhibit until Ctrl-C
  no-sleep status                                    list current sleep/idle inhibitors

Blocks: idle timeout, programmatic suspend, and lid-close suspend.
EOF
}

if [[ ${1:-} == status ]]; then
  # Only MODE=block actually prevents sleep/idle; MODE=delay rows are 5s
  # cleanup hooks and aren't this script's concern.
  out=$(systemd-inhibit --list --no-pager)
  blockers=$(printf '%s\n' "$out" | awk 'NR>1 && $NF=="block"')
  if [[ -z $blockers ]]; then
    echo "no sleep/idle blockers"
    exit 0
  fi
  printf '%s\n%s\n' "$(printf '%s\n' "$out" | head -n 1)" "$blockers"
  exit 0
fi

why="user-requested"

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --why)
    why="${2:?--why requires an argument}"
    shift 2
    ;;
  --why=*)
    why="${1#--why=}"
    shift
    ;;
  *) break ;;
  esac
done

if [[ $# -eq 0 ]]; then
  set -- sleep infinity
elif [[ $1 == "--" ]]; then
  shift
  [[ $# -gt 0 ]] || {
    usage
    exit 2
  }
else
  set -- sleep "$1"
fi

# idle             — blocks hypridle/systemd idle timeout
# sleep            — blocks `systemctl suspend` and other programmatic suspends
# handle-lid-switch — blocks logind from acting on lid close (default: suspend)
exec systemd-inhibit \
  --what=idle:sleep:handle-lid-switch \
  --who=no-sleep \
  --why="$why" \
  -- "$@"
