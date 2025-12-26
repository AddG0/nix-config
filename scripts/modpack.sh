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
  list                     List all modpacks

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

cmd_list() {
	ls -1 "$MODPACKS_DIR"
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
list)
	cmd_list
	;;
*)
	usage
	;;
esac
