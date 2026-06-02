#!/usr/bin/env bash
# Updates pkgs/proton-cachyos/default.nix to the latest proton-cachyos build
# published on the CachyOS mirror. The mirror isn't a forge nix-update can
# parse, so this script does the discovery itself.
set -euo pipefail

FLAKE_ROOT=$(git rev-parse --show-toplevel)
DEFAULT_NIX="$FLAKE_ROOT/pkgs/proton-cachyos/default.nix"
MIRROR="https://mirror.cachyos.org/repo/x86_64/cachyos"

latest=$(
  curl -sfL "$MIRROR/" |
    grep -oE 'proton-cachyos-1:[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-x86_64\.pkg\.tar\.zst' |
    sort -uV |
    tail -1
)

if [[ -z $latest ]]; then
  echo "proton-cachyos: no candidate found on $MIRROR/" >&2
  exit 1
fi

re='proton-cachyos-1:([0-9]+\.[0-9]+)\.([0-9]+)-([0-9]+)-x86_64\.pkg\.tar\.zst'
[[ $latest =~ $re ]] || {
  echo "proton-cachyos: failed to parse '$latest'" >&2
  exit 1
}
new_base="${BASH_REMATCH[1]}"
new_release="${BASH_REMATCH[2]}"
new_pkgrel="${BASH_REMATCH[3]}"

cur_base=$(sed -nE 's/^  base = "([^"]+)";/\1/p' "$DEFAULT_NIX")
cur_release=$(sed -nE 's/^  release = "([^"]+)";/\1/p' "$DEFAULT_NIX")
cur_pkgrel=$(sed -nE 's/^  pkgrel = "([^"]+)";/\1/p' "$DEFAULT_NIX")

if [[ $cur_base == "$new_base" && $cur_release == "$new_release" && $cur_pkgrel == "$new_pkgrel" ]]; then
  echo "proton-cachyos: already at $new_base.$new_release-$new_pkgrel"
  exit 0
fi

echo "proton-cachyos: $cur_base.$cur_release-$cur_pkgrel -> $new_base.$new_release-$new_pkgrel"

raw=$(nix-prefetch-url \
  --name "proton-cachyos-${new_base}.${new_release}-${new_pkgrel}.pkg.tar.zst" \
  --type sha256 \
  "$MIRROR/$latest")
sri=$(nix hash convert --hash-algo sha256 --to sri "$raw")

sed -i \
  -e "s|^  base = \".*\";|  base = \"$new_base\";|" \
  -e "s|^  release = \".*\";|  release = \"$new_release\";|" \
  -e "s|^  pkgrel = \".*\";|  pkgrel = \"$new_pkgrel\";|" \
  -e "s|hash = \"sha256-[^\"]*\";|hash = \"$sri\";|" \
  "$DEFAULT_NIX"
