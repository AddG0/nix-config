#!/usr/bin/env bash
# Block until Steam has no in-progress downloads.
#
# Steam stages partial download data into each library's `steamapps/downloading/`
# directory while a download is active, and removes each app's subfolder when
# that app finishes. Wait for every library's `downloading/` to stay empty for
# `quiet_for` seconds so a brief gap between two queued downloads doesn't end
# the wait early.
#
# Intended use:
#   no-sleep --why "steam download" -- steam-download-wait

set -eu

interval=10
quiet_for=60

while [[ $# -gt 0 ]]; do
	case "$1" in
	--interval)
		interval="${2:?--interval requires seconds}"
		shift 2
		;;
	--quiet-for)
		quiet_for="${2:?--quiet-for requires seconds}"
		shift 2
		;;
	-h | --help)
		cat <<EOF
Usage: steam-download-wait [--interval <sec>] [--quiet-for <sec>]
  --interval   poll period in seconds (default: $interval)
  --quiet-for  seconds the downloading dirs must stay empty before exit (default: $quiet_for)
EOF
		exit 0
		;;
	*)
		echo "unknown arg: $1" >&2
		exit 2
		;;
	esac
done

# Discover steamapps roots: the two default install locations plus any extra
# library folders Steam tracks in libraryfolders.vdf (external drives etc.).
roots=()
for default in "$HOME/.steam/steam/steamapps" "$HOME/.local/share/Steam/steamapps"; do
	[[ -d $default ]] && roots+=("$default")
done
for root in "${roots[@]}"; do
	vdf="$root/libraryfolders.vdf"
	[[ -e $vdf ]] || continue
	while IFS= read -r path; do
		[[ -d "$path/steamapps" ]] && roots+=("$path/steamapps")
	done < <(awk -F'"' '/"path"/{print $4}' "$vdf")
done

if [[ ${#roots[@]} -eq 0 ]]; then
	echo "steam-download-wait: no Steam library found" >&2
	exit 1
fi

is_downloading() {
	for root in "${roots[@]}"; do
		d="$root/downloading"
		[[ -d $d ]] || continue
		if [[ -n "$(ls -A "$d" 2>/dev/null)" ]]; then
			return 0
		fi
	done
	return 1
}

elapsed_quiet=0
while true; do
	if is_downloading; then
		elapsed_quiet=0
	else
		elapsed_quiet=$((elapsed_quiet + interval))
		if [[ $elapsed_quiet -ge $quiet_for ]]; then
			exit 0
		fi
	fi
	sleep "$interval"
done
