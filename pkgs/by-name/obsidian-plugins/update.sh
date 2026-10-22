#!/usr/bin/env bash
set -euo pipefail

# Arguments: <pname> <repo> <package_nix_path>
pname="$1"
repo="$2"
package_nix="$3"

# Get latest release tag from GitHub API
latest_version=$(curl -sSfL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')
# Remove 'v' prefix if present
version="${latest_version#v}"

echo "Checking ${pname}... latest: ${version}"

# Identify files to track (standard for most Obsidian plugins)
files=("main.js" "manifest.json" "styles.css")
declare -A new_hashes

for file in "${files[@]}"; do
  # Attempt to find the file in the latest release assets or the source tree at that tag
  url="https://github.com/${repo}/raw/tags/${latest_version}/${file}"
  if curl -sSfL "$url" >/dev/null; then
    hash=$(curl -sSfL "$url" | sha256sum | cut -d' ' -f1)
    new_hashes["$file"]="sha256-${hash}"
  else
    # Log and skip if file is missing (some plugins don't have CSS)
    echo "Warning: ${file} not found for ${pname} at ${latest_version}" >&2
  fi
done

# Read current version
cur_version=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$package_nix")

if [[ $cur_version == "$version" ]]; then
  echo "${pname} is already up to date"
  exit 0
fi

# Update version
sed -i "s/^  version = \".*\";/  version = \"${version}\";/" "$package_nix"

# Update hashes
for file in "${!new_hashes[@]}"; do
  sed -i "s|^    \"${file}\" = \"sha256-[^\"}]*\";|    \"${file}\" = \"${new_hashes[$file]}\";|" "$package_nix"
done

echo "Updated ${pname} to ${version}"
