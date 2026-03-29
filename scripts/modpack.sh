#!/usr/bin/env bash
# Minecraft modpack management script for packwiz
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MODPACKS_DIR="$REPO_DIR/home/common/optional/gaming/minecraft/modpacks"

usage() {
	cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  update <name> <mod>      Update a specific mod
  update-all <name>        Update all mods
  add <name> <mod>         Add a mod from Modrinth
  remove <name> <mod>      Remove a mod
  refresh <name>           Refresh packwiz index
  serve <name>             Start packwiz dev server
  list                     List all modpacks
  compat <name> <version>  Check mod compatibility for a Minecraft version

For development, use: just modpack-serve <name>
This starts packwiz serve for rapid iteration.

Examples:
  $(basename "$0") update main-1.20.1 sodium
  $(basename "$0") add main-1.20.1 "performance mod"
EOF
	exit 1
}

check_modpack() {
	local name="$1"
	if [ ! -d "$MODPACKS_DIR/$name" ]; then
		echo "Error: Modpack '$name' not found in $MODPACKS_DIR"
		exit 1
	fi
}

cmd_update() {
	local name="$1"
	local mod="$2"
	check_modpack "$name"
	cd "$MODPACKS_DIR/$name"
	packwiz update "$mod" -y
}

cmd_update_all() {
	local name="$1"
	check_modpack "$name"
	cd "$MODPACKS_DIR/$name"
	packwiz update --all -y
}

cmd_add() {
	local name="$1"
	local mod="$2"
	check_modpack "$name"
	cd "$MODPACKS_DIR/$name"
	packwiz modrinth add "$mod"
}

cmd_remove() {
	local name="$1"
	local mod="$2"
	check_modpack "$name"
	cd "$MODPACKS_DIR/$name"
	packwiz remove "$mod"
}

cmd_refresh() {
	local name="$1"
	check_modpack "$name"
	cd "$MODPACKS_DIR/$name"
	packwiz refresh
}

cmd_serve() {
	local name="$1"
	check_modpack "$name"
	echo "Set Prism Launcher Pre-launch command to:"
	echo '  "$INST_JAVA" -jar $HOME/.local/share/packwiz/packwiz-installer-bootstrap.jar http://localhost:8080/pack.toml'
	echo ""
	echo "Starting packwiz serve... (Ctrl+C to stop)"
	echo ""
	cd "$MODPACKS_DIR/$name"
	packwiz serve
}

cmd_list() {
	ls -1 "$MODPACKS_DIR"
}

cmd_compat() {
	local name="$1"
	local target_version="$2"
	check_modpack "$name"

	local mods_dir="$MODPACKS_DIR/$name/mods"
	local tmpdir
	tmpdir=$(mktemp -d)
	trap 'rm -rf "'"$tmpdir"'"' EXIT

	echo "Checking mod compatibility for Minecraft $target_version..."
	echo ""

	# Launch API checks in parallel batches (10 at a time to avoid rate limits)
	local pids=()
	local batch_size=10
	local count=0
	for toml in "$mods_dir"/*.pw.toml; do
		[ -f "$toml" ] || continue
		local mod_name mod_id
		mod_name=$(grep '^name' "$toml" | head -1 | sed 's/.*= *"//;s/".*//')
		mod_id=$(grep 'mod-id' "$toml" | head -1 | sed 's/.*= *"//;s/".*//')
		[ -z "$mod_id" ] && continue

		(
			local response versions
			response=$(curl -s --retry 2 --retry-delay 1 -H "User-Agent: nix-config-modpack/1.0" \
				"https://api.modrinth.com/v2/project/$mod_id/version?loaders=%5B%22fabric%22%5D&game_versions=%5B%22$target_version%22%5D")
			versions=$(echo "$response" | jq -r 'length' 2>/dev/null || echo "0")

			if [ "$versions" -gt 0 ] 2>/dev/null; then
				echo "supported|$mod_name" >"$tmpdir/$mod_id"
			else
				local best_response best
				best_response=$(curl -s --retry 2 --retry-delay 1 -H "User-Agent: nix-config-modpack/1.0" \
					"https://api.modrinth.com/v2/project/$mod_id/version?loaders=%5B%22fabric%22%5D")
				best=$(echo "$best_response" | jq -r '[.[].game_versions[]] | unique | map(select(startswith("1.21"))) | sort_by(split(".") | map(tonumber? // 0)) | last // "none"' 2>/dev/null || echo "unknown")
				echo "unsupported|$mod_name|$best" >"$tmpdir/$mod_id"
			fi
		) &
		pids+=($!)
		count=$((count + 1))

		# Wait for batch to complete before launching more
		if [ $((count % batch_size)) -eq 0 ]; then
			for pid in "${pids[@]}"; do
				wait "$pid" 2>/dev/null || true
			done
			pids=()
		fi
	done

	# Wait for remaining jobs
	for pid in "${pids[@]}"; do
		wait "$pid" 2>/dev/null || true
	done

	# Collect results
	local supported=()
	local unsupported=()
	local closest=()

	for result in "$tmpdir"/*; do
		[ -f "$result" ] || continue
		local line
		line=$(cat "$result")
		local status
		status=$(echo "$line" | cut -d'|' -f1)
		if [ "$status" = "supported" ]; then
			supported+=("$(echo "$line" | cut -d'|' -f2)")
		else
			unsupported+=("$(echo "$line" | cut -d'|' -f2)")
			closest+=("$(echo "$line" | cut -d'|' -f3)")
		fi
	done

	# Sort arrays
	IFS=$'\n' supported=($(sort <<<"${supported[*]}"))
	unset IFS
	IFS=$'\n' unsupported_sorted=($(for i in "${!unsupported[@]}"; do echo "${unsupported[$i]}|${closest[$i]}"; done | sort))
	unset IFS
	unsupported=()
	closest=()
	for entry in "${unsupported_sorted[@]}"; do
		unsupported+=("$(echo "$entry" | cut -d'|' -f1)")
		closest+=("$(echo "$entry" | cut -d'|' -f2)")
	done

	# Print results
	echo "=== SUPPORTED ($target_version) ==="
	printf '  \033[32m✓\033[0m %s\n' "${supported[@]}"
	echo ""

	if [ ${#unsupported[@]} -gt 0 ]; then
		echo "=== NOT SUPPORTED ==="
		for i in "${!unsupported[@]}"; do
			printf '  \033[31m✗\033[0m %-40s (latest 1.21.x: %s)\n' "${unsupported[$i]}" "${closest[$i]}"
		done
		echo ""
		echo "Summary: ${#supported[@]} supported, ${#unsupported[@]} unsupported"
	else
		echo "All ${#supported[@]} mods support $target_version!"
	fi
}

# Main
[ $# -lt 1 ] && usage

case "$1" in
update)
	[ $# -lt 3 ] && usage
	cmd_update "$2" "$3"
	;;
update-all)
	[ $# -lt 2 ] && usage
	cmd_update_all "$2"
	;;
add)
	[ $# -lt 3 ] && usage
	cmd_add "$2" "$3"
	;;
remove)
	[ $# -lt 3 ] && usage
	cmd_remove "$2" "$3"
	;;
refresh)
	[ $# -lt 2 ] && usage
	cmd_refresh "$2"
	;;
serve)
	[ $# -lt 2 ] && usage
	cmd_serve "$2"
	;;
list)
	cmd_list
	;;
compat)
	[ $# -lt 3 ] && usage
	cmd_compat "$2" "$3"
	;;
*)
	usage
	;;
esac
