#!/usr/bin/env bash
# Compare vscode-marketplace vs vscode-marketplace-release versions
# Usage: ./compare-vscode-extensions.sh [--fix] [extension-name]
# Example: ./compare-vscode-extensions.sh redhat.java
#          ./compare-vscode-extensions.sh --fix

set -euo pipefail

FLAKE_PATH="${FLAKE_PATH:-/home/addg/nix-config}"
FIX_MODE=false

# Parse flags
while [[ $# -gt 0 ]]; do
	case "$1" in
	--fix)
		FIX_MODE=true
		shift
		;;
	*)
		break
		;;
	esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Extensions locked to -release (skip auto-fix)
# Add extensions here that must stay on release for compatibility reasons
LOCKED_RELEASE=(
	# Java extensions (OSGi bundle compatibility)
	"redhat.java"
	"vscjava.vscode-java-debug"
	"vscjava.vscode-java-test"
	"vscjava.vscode-maven"
	"vscjava.vscode-java-dependency"
	"vscjava.vscode-gradle"
	"vmware.vscode-spring-boot"
	"vscjava.vscode-spring-initializr"
	# GitHub Copilot
	"github.copilot"
	"github.copilot-chat"
)

is_locked() {
	local ext="$1"
	for locked in "${LOCKED_RELEASE[@]}"; do
		[[ $ext == "$locked" ]] && return 0
	done
	return 1
}

# Temp dir for fixes
TMPDIR=$(mktemp -d)
FIXES_FILE="$TMPDIR/fixes"
touch "$FIXES_FILE"
trap 'rm -rf "$TMPDIR"' EXIT

# Otherwise, find all extensions in config and check them
echo "Scanning extension files..."

# Extract extension names and their current source
declare -A ext_sources
while IFS= read -r line; do
	if [[ $line =~ pkgs\.vscode-marketplace-release\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+) ]]; then
		ext="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
		ext_sources["$ext"]="release"
	elif [[ $line =~ pkgs\.vscode-marketplace\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+) ]]; then
		ext="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
		[[ -z ${ext_sources[$ext]:-} ]] && ext_sources["$ext"]="market"
	fi
done < <(grep -rh "vscode-marketplace" "$FLAKE_PATH/home/common/optional/development/ide/vscode/extensions" 2>/dev/null)

# Get sorted list of extensions
mapfile -t extensions < <(printf '%s\n' "${!ext_sources[@]}" | sort)

total=${#extensions[@]}
echo "Found $total extensions."

# Build nix expression to get all versions at once
echo "Fetching versions..."

# Generate nix expression that outputs JSON with all versions
nix_expr="let
  pkgs = (builtins.getFlake \"${FLAKE_PATH}\").nixosConfigurations.demon.pkgs;
  getVer = set: pub: name: (set.\${pub}.\${name}.version or \"N/A\");
  market = pkgs.vscode-marketplace;
  release = pkgs.vscode-marketplace-release;
in {"

for ext in "${extensions[@]}"; do
	publisher="${ext%%.*}"
	name="${ext#*.}"
	nix_expr+="
  \"${ext}\" = {
    release = getVer release \"${publisher}\" \"${name}\";
    market = getVer market \"${publisher}\" \"${name}\";
  };"
done

nix_expr+="
}"

# Run single nix eval and get JSON
versions_json=$(nix eval --impure --json --expr "$nix_expr" 2>/dev/null)

echo ""
# Print header
printf "%-45s  %-8s  %-22s  %-22s  %s\n" "EXTENSION" "CURRENT" "RELEASE" "MARKETPLACE" "ACTION"
printf "%s\n" "$(printf '=%.0s' {1..130})"

# Process results
for ext in "${extensions[@]}"; do
	current_source="${ext_sources[$ext]}"

	# Extract versions from JSON
	release_ver=$(echo "$versions_json" | jq -r ".\"${ext}\".release // \"N/A\"")
	marketplace_ver=$(echo "$versions_json" | jq -r ".\"${ext}\".market // \"N/A\"")

	# Determine best source and status
	best_source="same"
	status=""

	# Check if extension is locked
	locked=false
	is_locked "$ext" && locked=true

	if [[ $release_ver == "N/A" && $marketplace_ver == "N/A" ]]; then
		status="${RED}NOT FOUND${NC}"
	elif [[ $release_ver == "N/A" ]]; then
		best_source="market"
		status="${YELLOW}market only${NC}"
	elif [[ $marketplace_ver == "N/A" ]]; then
		best_source="release"
		status="${YELLOW}release only${NC}"
	elif [[ $release_ver == "$marketplace_ver" ]]; then
		status="${GREEN}==${NC}"
	elif [[ $locked == true ]]; then
		# Locked extensions always show as locked, regardless of version
		status="${BLUE}🔒 locked${NC}"
	else
		# Compare versions
		higher=$(printf '%s\n%s' "$release_ver" "$marketplace_ver" | sort -V | tail -n1)
		if [[ $higher == "$release_ver" ]]; then
			best_source="release"
			if [[ $current_source == "release" ]]; then
				status="${GREEN}✓ release${NC}"
			else
				status="${RED}→ release${NC}"
			fi
		else
			best_source="market"
			if [[ $current_source == "market" ]]; then
				status="${GREEN}✓ market${NC}"
			else
				status="${RED}→ market${NC}"
			fi
		fi
	fi

	printf "%-45s  %-8s  %-22s  %-22s  %b\n" "$ext" "$current_source" "$release_ver" "$marketplace_ver" "$status"

	# Record fix if needed (skip locked extensions)
	if [[ $locked == false && $best_source != "same" && $best_source != "$current_source" ]]; then
		echo "$ext:$current_source:$best_source" >>"$FIXES_FILE"
	fi
done

echo ""
echo "Legend:"
echo -e "  ${GREEN}✓${NC}  = Already using best source"
echo -e "  ${RED}→${NC}  = Should switch to indicated source"
echo -e "  ${GREEN}==${NC} = Versions are identical"
echo -e "  ${BLUE}🔒${NC} = Locked to release (skip auto-fix)"

# Apply fixes if --fix mode
if [[ $FIX_MODE == true ]]; then
	fix_count=$(wc -l <"$FIXES_FILE")
	if [[ $fix_count -eq 0 ]]; then
		echo ""
		echo -e "${GREEN}All extensions are already using the best source!${NC}"
	else
		echo ""
		echo -e "${YELLOW}Applying $fix_count fixes...${NC}"

		while IFS=: read -r ext from_source to_source; do
			publisher="${ext%%.*}"
			name="${ext#*.}"

			# Find the file containing this extension
			file=$(grep -rl "vscode-marketplace.*\.${publisher}\.${name}" \
				"$FLAKE_PATH/home/common/optional/development/ide/vscode/extensions" 2>/dev/null | head -1)

			if [[ -n $file ]]; then
				if [[ $to_source == "release" ]]; then
					# Change from marketplace to marketplace-release
					sed -i "s/vscode-marketplace\.${publisher}\.${name}/vscode-marketplace-release.${publisher}.${name}/g" "$file"
				else
					# Change from marketplace-release to marketplace
					sed -i "s/vscode-marketplace-release\.${publisher}\.${name}/vscode-marketplace.${publisher}.${name}/g" "$file"
				fi
				echo -e "  ${GREEN}✓${NC} $ext: $from_source → $to_source (${file#$FLAKE_PATH/})"
			else
				echo -e "  ${RED}✗${NC} $ext: Could not find file"
			fi
		done <"$FIXES_FILE"

		echo ""
		echo -e "${GREEN}Done! Run 'nixos-rebuild' to apply changes.${NC}"
	fi
fi
