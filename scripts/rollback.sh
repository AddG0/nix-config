#!/usr/bin/env bash
set -eou pipefail
# shellcheck disable=SC2086

# Source helpers
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Usage: $0 [-h] [-v] [generation]
#  -h             Display this help message.
#  -v             Enable verbose/debug output.
#  generation     Generation number; if not provided, rollback to previous generation.

usage() {
  echo "Usage: $0 [-h] [-v] [generation]"
  exit 1
}

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Handle verbose flag first
handle_verbose_flag "$@"

# Parse remaining options
while getopts "h" opt; do
  case "$opt" in
  h) usage ;;
  *) usage ;;
  esac
done
shift $((OPTIND - 1))

# Get generation number (optional)
GENERATION="${1:-}"

# OS-specific rollback function for Darwin
rollback_darwin() {
  log_info "Starting Darwin rollback"
  if [ -n "${GENERATION}" ]; then
    log_info "Rolling back to generation ${GENERATION}"
    if [ ! -L "/nix/var/nix/profiles/system-${GENERATION}-link" ]; then
      log_error "Generation ${GENERATION} does not exist"
      exit 1
    fi
    sudo /nix/var/nix/profiles/system-${GENERATION}-link/bin/darwin-rebuild activate
  else
    log_info "Rolling back to previous generation"
    sudo darwin-rebuild --rollback
  fi
}

# OS-specific rollback function for Linux
rollback_linux() {
  log_info "Starting Linux rollback"
  if [ -n "${GENERATION}" ]; then
    log_info "Rolling back to generation ${GENERATION}"
    if [ ! -L "/nix/var/nix/profiles/system-${GENERATION}-link" ]; then
      log_error "Generation ${GENERATION} does not exist"
      exit 1
    fi
    sudo /nix/var/nix/profiles/system-${GENERATION}-link/bin/switch-to-configuration switch
  else
    log_info "Rolling back to previous generation"
    sudo nixos-rebuild switch --rollback
  fi
}

# Execute the rollback
log_info "====== ROLLBACK ======"
if [ "$(uname -s)" == "Darwin" ]; then
  rollback_darwin
else
  rollback_linux
fi

log_info "====== ROLLBACK COMPLETE ======"
log_info "Rolled back successfully"
