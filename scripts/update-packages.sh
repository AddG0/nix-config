#!/usr/bin/env bash

set -euo pipefail

# Source helpers
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Function to check if a package has a new version
check_package_version() {
	local package=$1
	local pkg_file="$package/package.nix"

	if [ ! -f "$pkg_file" ]; then
		red "Package file not found: $pkg_file"
		return 1
	fi

	# Extract current version from package.nix
	local current_version=$(grep -m 1 "version = " "$pkg_file" | sed 's/.*version = "\(.*\)";/\1/')
	blue "Current version of $(basename "$package"): $current_version"

	# For GitHub-based packages, check for new releases
	if grep -q "fetchFromGitHub" "$pkg_file"; then
		local owner=$(grep -m 1 "owner = " "$pkg_file" | sed 's/.*owner = "\(.*\)";/\1/')
		local repo=$(grep -m 1 "repo = " "$pkg_file" | sed 's/.*repo = "\(.*\)";/\1/')

		if [ -n "$owner" ] && [ -n "$repo" ]; then
			blue "Checking GitHub releases for $owner/$repo..."
			# Use nix-update to check for updates
			if nix-update "$(basename "$package")" --version=stable; then
				green "New version available for $(basename "$package")"
			else
				yellow "No new version available for $(basename "$package")"
			fi
		fi
	fi
}

# Function to update a package
update_package() {
	local package=$1
	local pkg_name=$(basename "$package")
	blue "Updating $pkg_name..."

	# First check if there's a new version
	check_package_version "$package"

	# Then try to update using nix-update
	if nix-update "$pkg_name" --commit --version=stable; then
		green "Successfully updated $pkg_name"
	else
		red "Failed to update $pkg_name"
	fi
}

# Parse command line arguments
CHECK_ONLY=false
while getopts "c" opt; do
	case "$opt" in
	c) CHECK_ONLY=true ;;
	*) usage ;;
	esac
done

green "Starting package updates..."

# Find all package.nix files recursively in pkgs directory
while IFS= read -r -d '' pkg_file; do
	pkg_dir=$(dirname "$pkg_file")
	if [ "$CHECK_ONLY" = true ]; then
		check_package_version "$pkg_dir"
	else
		update_package "$pkg_dir"
	fi
done < <(find pkgs -name "package.nix" -print0)

# Update nixpkgs itself
blue "Updating nixpkgs..."
if nix-channel --update; then
	green "Successfully updated nixpkgs"
else
	red "Failed to update nixpkgs"
fi

green "All updates completed!"
