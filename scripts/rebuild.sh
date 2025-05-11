#!/usr/bin/env bash
set -eou pipefail
# shellcheck disable=SC2086

# Source helpers
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Usage: $0 [-h] [-t] [-v] [host]
#  -h             Display this help message.
#  -t             Enable trace mode (adds --show-trace flag).
#  -v             Enable verbose/debug output.
#  host           Host name; if not provided, defaults to the output of hostname.

usage() {
	echo "Usage: $0 [-h] [-t] [-v] [host]"
	exit 1
}

# Check if a command exists
command_exists() {
	command -v "$1" &>/dev/null
}

# Default configuration values
TRACE="false"
VERBOSE="false"

# Parse options using getopts
while getopts "htv" opt; do
	case "$opt" in
	h) usage ;;
	t) TRACE="true" ;;
	v) VERBOSE="true" ;;
	*) usage ;;
	esac
done
shift $((OPTIND - 1))

# Set host (defaults to the output of hostname)
HOST="${1:-$(hostname)}"

# Build switch arguments for nix commands
switch_args=""
if [ "${TRACE}" = "true" ]; then
	switch_args+="--show-trace "
fi
switch_args+="--impure --flake .#${HOST} switch"

# OS-specific rebuild function for Darwin
rebuild_darwin() {
	blue "Starting Darwin rebuild"
	mkdir -p "${HOME}/.config/nix"
	local CONF="${HOME}/.config/nix/nix.conf"
	if [ ! -f "${CONF}" ]; then
		cat <<-EOF >"${CONF}"
			            experimental-features = nix-command flakes
		EOF
	fi

	# Ensure git is installed for tagging/version control
	if ! command_exists git; then
		green "Installing Xcode tools..."
		xcode-select --install || {
			red "xcode-select installation failed"
			return 1
		}
	fi

	green "====== REBUILD ======"
	if ! command_exists darwin-rebuild; then
		blue "darwin-rebuild not found; using 'nix run nix-darwin'"
		nix run nix-darwin -- switch ${switch_args} --impure
	else
		blue "Using darwin-rebuild with arguments: ${switch_args}"
		darwin-rebuild ${switch_args}
	fi
}

# OS-specific rebuild function for Linux (or non‑Darwin)
rebuild_linux() {
	blue "Starting Linux rebuild"
	green "====== REBUILD ======"
	if command_exists nh; then
		blue "Using nh command for rebuild"
		nh os switch . -- --impure --show-trace
	else
		blue "Using sudo nixos-rebuild with arguments: ${switch_args}"
		sudo nixos-rebuild ${switch_args}
	fi
}

# Execute the rebuild command
if [ "$(uname -s)" == "Darwin" ]; then
	rebuild_darwin
else
	rebuild_linux
fi

green "====== POST‑REBUILD ======"
green "Rebuilt successfully"

# Check for pending git changes before tagging the commit as buildable.
if git diff --exit-code >/dev/null && git diff --staged --exit-code >/dev/null; then
	if git tag --points-at HEAD | grep -q buildable; then
		yellow "Current commit is already tagged as buildable"
	else
		git tag buildable-"$(date +%Y%m%d%H%M%S)" -m ''
		green "Tagged current commit as buildable"
	fi
else
	yellow "WARN: There are pending changes that could affect the build. Commit them before tagging."
fi
