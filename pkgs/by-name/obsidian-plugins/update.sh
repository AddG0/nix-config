#!/usr/bin/env bash
set -euo pipefail

# Arguments: <pname> <repo> <package_nix_path>
pname="$1"
repo="$2"
# Flake eval hands us the store copy; nix-update runs us from the repo root.
package_nix="${3#/nix/store/*-source/}"

if [[ ! -w $package_nix ]]; then
  echo "${pname}: cannot write ${package_nix} (from $3); run from the repo root" >&2
  exit 1
fi

tag=$(curl -sSfL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')
version="${tag#v}"
cur_version=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$package_nix")

echo "Checking ${pname}... current: ${cur_version}, latest: ${version}"

if [[ $cur_version == "$version" ]]; then
  echo "${pname} is already up to date"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Hash the release assets mkPlugin fetches, for each file the package already pins.
declare -A new_hashes
mapfile -t files < <(sed -nE 's/^    "([^"]+)" = "sha256-[^"]*";/\1/p' "$package_nix")
for file in "${files[@]}"; do
  url="https://github.com/${repo}/releases/download/${tag}/${file}"
  if ! curl -sSfL -o "$tmp/$file" "$url"; then
    echo "${pname}: failed to fetch ${url}" >&2
    exit 1
  fi
  new_hashes["$file"]="sha256-$(openssl dgst -sha256 -binary "$tmp/$file" | base64 -w0)"
done

sed -i "s/^  version = \".*\";/  version = \"${version}\";/" "$package_nix"
for file in "${!new_hashes[@]}"; do
  sed -i "s|^    \"${file}\" = \"sha256-[^\"]*\";|    \"${file}\" = \"${new_hashes[$file]}\";|" "$package_nix"
done

echo "Update ${pname} ${cur_version} -> ${version}"
