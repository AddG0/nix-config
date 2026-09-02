#!/usr/bin/env bash
# Updates pkgs/sqry/default.nix to the latest sqry release.
#
# sqry ships prebuilt musl binaries rather than a source tarball, so the
# derivation has no `src` — it fetchurl's two binaries per architecture. Without
# a `src` attribute nix-update bails with "Could not find a url in the
# derivations src attribute", so it can't drive this package at all.
set -euo pipefail

FLAKE_ROOT=$(git rev-parse --show-toplevel)
DEFAULT_NIX="$FLAKE_ROOT/pkgs/sqry/default.nix"
REPO="verivus-oss/sqry"
BASE="https://github.com/$REPO/releases/download"

# Capture first: curl exits 23 when `grep -m1` closes its pipe, and pipefail
# turns that into a silent failure of the whole script.
release_json=$(curl -sfL "https://api.github.com/repos/$REPO/releases/latest")
new_version=$(sed -nE 's/.*"tag_name": *"v?([^"]+)".*/\1/p' <<<"$release_json" | head -n1)

if [[ -z $new_version ]]; then
  echo "sqry: could not determine the latest release" >&2
  exit 1
fi

cur_version=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$DEFAULT_NIX")

if [[ $cur_version == "$new_version" ]]; then
  echo "sqry: already at $new_version"
  exit 0
fi

echo "sqry: $cur_version -> $new_version"

sri_for() {
  local raw
  raw=$(nix-prefetch-url --type sha256 "$BASE/v$new_version/$1-linux-$2-musl")
  nix hash convert --hash-algo sha256 --to sri "$raw"
}

# These arch and binary names have to match the arches/hashes tables in default.nix.
x86_64_sqry=$(sri_for sqry x86_64)
x86_64_mcp=$(sri_for sqry-mcp x86_64)
arm64_sqry=$(sri_for sqry arm64)
arm64_mcp=$(sri_for sqry-mcp arm64)

sed -i "s|^  version = \".*\";|  version = \"$new_version\";|" "$DEFAULT_NIX"

# Both arch blocks hold the same two keys, hence tracking the current block.
# Not a perl s///: SRI hashes are base64 and contain "/", which terminates it.
awk -v x1="$x86_64_sqry" -v x2="$x86_64_mcp" -v a1="$arm64_sqry" -v a2="$arm64_mcp" '
  /^    x86_64 = \{/ { arch = "x" }
  /^    arm64 = \{/ { arch = "a" }
  /^      sqry = "sha256-/ { sub(/"sha256-[^"]*"/, "\"" (arch == "x" ? x1 : a1) "\"") }
  /^      sqry-mcp = "sha256-/ { sub(/"sha256-[^"]*"/, "\"" (arch == "x" ? x2 : a2) "\"") }
  { print }
' "$DEFAULT_NIX" >"$DEFAULT_NIX.new" && mv "$DEFAULT_NIX.new" "$DEFAULT_NIX"

# A shape change in default.nix would make the substitution a silent no-op and
# leave the stale hashes in place, so confirm every new hash landed.
for sri in "$x86_64_sqry" "$x86_64_mcp" "$arm64_sqry" "$arm64_mcp"; do
  grep -qF "$sri" "$DEFAULT_NIX" || {
    echo "sqry: failed to write hash $sri — has the hashes table changed shape?" >&2
    exit 1
  }
done
