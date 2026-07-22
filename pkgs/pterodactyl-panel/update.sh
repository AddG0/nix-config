#!/usr/bin/env bash
# Bumps pkgs/pterodactyl-panel/default.nix to the latest pterodactyl/panel
# release. nix-update can't derive the version from a plain fetchurl of a
# release asset, so resolve the newest release tag ourselves, then let
# nix-update refresh both the src hash and the composer vendorHash.
set -euo pipefail

latest=$(
  curl -sfL "https://api.github.com/repos/pterodactyl/panel/releases/latest" |
    grep -oE '"tag_name": *"v[0-9]+\.[0-9]+\.[0-9]+"' |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' |
    sed 's/^v//'
)

if [[ -z $latest ]]; then
  echo "pterodactyl-panel: could not resolve latest release" >&2
  exit 1
fi

echo "pterodactyl-panel: latest release is $latest"

# nix-update rewrites the version, src hash and vendorHash in place.
exec nix-update --flake pterodactyl-panel --version "$latest"
