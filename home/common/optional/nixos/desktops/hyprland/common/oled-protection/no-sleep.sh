#!/usr/bin/env bash

usage() {
	cat <<'EOF'
Usage:
  no-sleep [--why <reason>] -- <command> [args...]   inhibit idle while command runs
  no-sleep [--why <reason>] <duration>               inhibit for duration (e.g. 2h, 30m)
  no-sleep [--why <reason>]                          inhibit until Ctrl-C
EOF
}

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

exec systemd-inhibit --what=idle --who=no-sleep --why="$why" -- "$@"
