#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#nix-update nixpkgs#jq nixpkgs#parallel --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$FLAKE_DIR/.update-logs"

source "$SCRIPT_DIR/helpers.sh"

# Discover packages as "name:version_policy:has_update_script" lines.
# Packages without a version attr or with nixUpdate.version = "skip" get "skip".
# When called with package names, narrows the eval to just those attrs (and
# throws if any are missing) so single-package invocations don't pay for a
# full-flake discovery.
discover_packages() {
	local system selected_expr
	system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"

	if [ $# -eq 0 ]; then
		selected_expr='pkgs'
	else
		local nix_names=""
		for name in "$@"; do
			nix_names+="\"$name\" "
		done
		selected_expr="builtins.listToAttrs (map (n:
        if builtins.hasAttr n pkgs
        then { name = n; value = builtins.getAttr n pkgs; }
        else throw \"package not found: \${n}\"
      ) [ $nix_names])"
	fi

	nix eval "$FLAKE_DIR#packages.$system" --apply "
    pkgs: builtins.mapAttrs (name: pkg: {
      version = if !(pkg ? version) then \"skip\"
        else (pkg.passthru.nixUpdate or {}).version or \"stable\";
      hasUpdateScript = (pkg.passthru or {}) ? updateScript;
    }) ($selected_expr)
  " --json | jq -r 'to_entries[] | "\(.key):\(.value.version):\(.value.hasUpdateScript)"'
}

export -f log_info log_error log_debug
export DEBUG_MODE FLAKE_DIR LOG_DIR RED GREEN YELLOW BLUE NC

# Extract a "version_before -> version_after" string for a package from its log.
# Falls back to just the current version, or empty if neither found.
parse_version_change() {
	local log="$1"
	local line
	if line=$(grep -m1 -E '^Update [^ ]+ -> [^ ]+' "$log" 2>/dev/null); then
		echo "$(awk '{print $2}' <<<"$line") -> $(awk '{print $4}' <<<"$line")"
		return
	fi
	if line=$(grep -m1 -oE '^Not updating version, already \S+' "$log" 2>/dev/null); then
		echo "${line#Not updating version, already }"
		return
	fi
	if line=$(grep -m1 -oE 'UPDATE_NIX_OLD_VERSION=\S+' "$log" 2>/dev/null); then
		echo "${line#UPDATE_NIX_OLD_VERSION=}"
		return
	fi
}
export -f parse_version_change

# Pull a useful one-line error excerpt out of a failed package's log.
extract_error_excerpt() {
	local log="$1"
	local line
	# Prefer the first nix-style "error: ..." line.
	if line=$(grep -m1 -E '^(error:|error \()' "$log" 2>/dev/null); then
		echo "$line"
		return
	fi
	# Otherwise the last non-empty, non-command line.
	tac "$log" | grep -m1 -vE '^(\$|===|\s*$)' || true
}
export -f extract_error_excerpt

update_one() {
	local pkg_name="${1%%:*}" rest="${1#*:}"
	local version_policy="${rest%%:*}" has_update_script="${rest#*:}"
	local log_file="$LOG_DIR/$pkg_name.log"

	[[ $version_policy == "skip" ]] && return 0

	{
		echo "=== $pkg_name ($version_policy) === $(date '+%Y-%m-%d %H:%M:%S')"
		if [[ $has_update_script == "true" ]]; then
			nix-update --flake "$pkg_name" --use-update-script 2>&1
		else
			nix-update --flake "$pkg_name" "--version=$version_policy" 2>&1
		fi
	} >"$log_file" 2>&1 && {
		local after_file="$LOG_DIR/snapshots/$pkg_name.after"
		local pkg_dir="$FLAKE_DIR/pkgs/$pkg_name"
		if [[ -d $pkg_dir ]]; then
			find "$pkg_dir" -type f -print0 | sort -z | xargs -0 md5sum 2>/dev/null >"$after_file" || true
		else
			: >"$after_file"
		fi
		local version_info
		version_info=$(parse_version_change "$log_file")
		if diff -q "$LOG_DIR/snapshots/$pkg_name.before" "$after_file" >/dev/null 2>&1; then
			if [[ -n $version_info ]]; then
				log_info "$pkg_name - up-to-date ($version_info)"
			else
				log_info "$pkg_name - up-to-date"
			fi
		else
			if [[ $version_info == *"->"* ]]; then
				log_info "$pkg_name - UPDATED $version_info"
			elif [[ -n $version_info ]]; then
				log_info "$pkg_name - UPDATED (files changed, version $version_info)"
			else
				log_info "$pkg_name - UPDATED (files changed)"
			fi
		fi
	} || {
		cp "$log_file" "$LOG_DIR/failed/$pkg_name.log"
		local err
		err=$(extract_error_excerpt "$log_file")
		if [[ -n $err ]]; then
			log_error "$pkg_name - FAILED: $err"
		else
			log_error "$pkg_name - FAILED (see .update-logs/failed/$pkg_name.log)"
		fi
		return 1
	}
}
export -f update_one

JOBS=10
while getopts "vj:" opt; do
	case "$opt" in
	v) DEBUG_MODE=true ;;
	j) JOBS="$OPTARG" ;;
	*)
		echo "Usage: $(basename "$0") [-v] [-j N] [package...]"
		exit 1
		;;
	esac
done
shift $((OPTIND - 1))

if [ $# -gt 0 ]; then
	log_info "Looking up requested packages: $*"
else
	log_info "Discovering packages from flake..."
fi

output=$(discover_packages "$@")
mapfile -t entries <<<"$output"
log_info "Found ${#entries[@]} packages"

# Split into updatable and skipped
to_update=()
skipped=0
skipped_names=()
for entry in "${entries[@]}"; do
	rest="${entry#*:}"
	if [[ ${rest%%:*} == "skip" ]]; then
		((skipped++)) || true
		skipped_names+=("${entry%%:*}")
	else
		to_update+=("$entry")
	fi
done

if [[ $skipped -gt 0 ]]; then
	log_info "Skipped $skipped packages: ${skipped_names[*]}"
fi
[[ ${#to_update[@]} -eq 0 ]] && {
	log_info "Nothing to update"
	exit 0
}

rm -rf "$LOG_DIR" && mkdir -p "$LOG_DIR/failed" "$LOG_DIR/snapshots"

# Snapshot file hashes before updating so we can detect real changes
for entry in "${to_update[@]}"; do
	pkg="${entry%%:*}"
	pkg_dir="$FLAKE_DIR/pkgs/$pkg"
	if [[ -d $pkg_dir ]]; then
		find "$pkg_dir" -type f -print0 | sort -z | xargs -0 md5sum 2>/dev/null >"$LOG_DIR/snapshots/$pkg.before" || true
	else
		: >"$LOG_DIR/snapshots/$pkg.before"
	fi
done

log_info "Updating ${#to_update[@]} packages with $JOBS parallel jobs..."
printf '%s\n' "${to_update[@]}" | parallel --halt never --line-buffer -j "$JOBS" update_one {}

# Summary
updated_pkgs=()
refreshed_pkgs=()
failed_pkgs=()
for entry in "${to_update[@]}"; do
	pkg="${entry%%:*}"
	log_file="$LOG_DIR/$pkg.log"
	if [[ -f "$LOG_DIR/failed/$pkg.log" ]]; then
		err=$(extract_error_excerpt "$log_file")
		failed_pkgs+=("$pkg|${err:-unknown error}")
		continue
	fi
	after_file="$LOG_DIR/snapshots/$pkg.after"
	if [[ -f $after_file ]] && ! diff -q "$LOG_DIR/snapshots/$pkg.before" "$after_file" >/dev/null 2>&1; then
		ver=$(parse_version_change "$log_file")
		if [[ $ver == *"->"* ]]; then
			updated_pkgs+=("$pkg|$ver")
		else
			refreshed_pkgs+=("$pkg|${ver:-version unknown}")
		fi
	fi
done

updated_count=${#updated_pkgs[@]}
refreshed_count=${#refreshed_pkgs[@]}
failed_count=${#failed_pkgs[@]}
unchanged_count=$((${#to_update[@]} - updated_count - refreshed_count - failed_count))

echo ""
log_info "Results: $updated_count updated, $refreshed_count refreshed, $unchanged_count unchanged, $failed_count failed, $skipped skipped"

if [[ $updated_count -gt 0 ]]; then
	echo ""
	log_info "Updated (version bumped):"
	for entry in "${updated_pkgs[@]}"; do
		printf '  - %s: %s\n' "${entry%%|*}" "${entry#*|}"
	done
fi

if [[ $refreshed_count -gt 0 ]]; then
	echo ""
	log_info "Refreshed (files changed, no version bump):"
	for entry in "${refreshed_pkgs[@]}"; do
		printf '  - %s (at %s)\n' "${entry%%|*}" "${entry#*|}"
	done
fi

if [[ $failed_count -gt 0 ]]; then
	echo ""
	log_warning "Failed packages:"
	for entry in "${failed_pkgs[@]}"; do
		printf '  - %s: %s\n' "${entry%%|*}" "${entry#*|}"
	done
	log_info "Full logs: .update-logs/failed/<package>.log"
fi
