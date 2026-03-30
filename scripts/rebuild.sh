#!/usr/bin/env bash
set -eou pipefail
# shellcheck disable=SC2086

# Source helpers
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Usage: $0 [-h] [-t] [-v] [-m mode] [host]
#  -h             Display this help message.
#  -t             Enable trace mode (adds --show-trace flag).
#  -v             Enable verbose/debug output.
#  -m mode        Rebuild mode: switch (default), boot, or test.
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
MODE="switch"

# Parse options
while getopts "hvtm:" opt; do
	case "$opt" in
	h) usage ;;
	v) DEBUG_MODE=true ;;
	t) TRACE="true" ;;
	m) MODE="$OPTARG" ;;
	*) usage ;;
	esac
done
shift $((OPTIND - 1))

# Validate mode
if [[ $MODE != "switch" && $MODE != "boot" && $MODE != "test" ]]; then
	log_error "Invalid mode: $MODE (must be 'switch', 'boot', or 'test')"
	exit 1
fi

# Set host (defaults to the output of hostname)
HOST="${1:-$(hostname)}"

# Build switch arguments for nix commands
TRACE_FLAG=""
switch_args=""
if [ "${TRACE}" = "true" ]; then
	TRACE_FLAG="--show-trace"
	switch_args+="--show-trace "
fi
switch_args+="--impure --flake .#${HOST} ${MODE}"

# OS-specific rebuild function for Darwin
rebuild_darwin() {
	log_info "Starting Darwin rebuild"
	mkdir -p "${HOME}/.config/nix"
	local CONF="${HOME}/.config/nix/nix.conf"
	if [ ! -f "${CONF}" ]; then
		cat <<-EOF >"${CONF}"
			            experimental-features = nix-command flakes
		EOF
	fi

	# Ensure git is installed for tagging/version control
	if ! command_exists git; then
		log_info "Installing Xcode tools..."
		xcode-select --install || {
			log_error "xcode-select installation failed"
			return 1
		}
	fi

	log_info "====== REBUILD ======"
	if command_exists nh && [ "${USE_NH:-true}" = "true" ]; then
		log_debug "Using nh darwin command for rebuild"
		nh darwin ${MODE} . ${TRACE_FLAG:+-- $TRACE_FLAG}
	elif command_exists darwin-rebuild; then
		log_debug "Using darwin-rebuild with arguments: ${switch_args}"
		# Run darwin-rebuild with sudo as required by the new activation model
		sudo darwin-rebuild ${switch_args}
	else
		log_debug "darwin-rebuild not found; using 'nix run nix-darwin'"
		sudo nix run nix-darwin -- switch ${switch_args}
	fi
}

# OS-specific rebuild function for Linux (or non‑Darwin)
rebuild_linux() {
	log_info "Starting Linux rebuild"
	log_info "====== REBUILD ======"
	if command_exists nh && [ "${USE_NH:-true}" = "true" ]; then
		log_debug "Using nh command for rebuild"
		nh os ${MODE} . ${TRACE_FLAG:+-- $TRACE_FLAG}
	else
		log_debug "Using sudo nixos-rebuild with arguments: ${switch_args}"
		sudo nixos-rebuild ${switch_args}
	fi
}

# Execute the rebuild command
if [ "$(uname -s)" == "Darwin" ]; then
	rebuild_darwin
else
	rebuild_linux
fi

log_info "====== POST‑REBUILD ======"
log_info "Rebuilt successfully"

# Check for pending git changes before tagging the commit as buildable.
if git diff --exit-code >/dev/null && git diff --staged --exit-code >/dev/null; then
	if git tag --points-at HEAD | grep -q buildable; then
		log_warning "Current commit is already tagged as buildable"
	else
		git tag buildable-"$(date +%Y%m%d%H%M%S)" -m ''
		log_info "Tagged current commit as buildable"
	fi
else
	log_warning "There are pending changes that could affect the build. Commit them before tagging."
fi
