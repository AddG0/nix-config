#!/usr/bin/env bash
# Update one Decky-store plugin's version+hash in ./default.nix from the store
# API. nix-update can't read the deckbrew store, so this is the plugin's
# passthru.updateScript (args: <store name> <pname>). The store `hash` is the
# artifact sha256 (hex) — it doubles as the fetchurl integrity and the URL.
# store-plugin.nix strips this shebang and wraps the body in
# writeShellApplication, which supplies the curl/jq/git/gawk PATH.
set -euo pipefail

store_name="$1"
pname="$2"
default_nix="$(git rev-parse --show-toplevel)/pkgs/decky/default.nix"

data="$(curl -sSfL https://plugins.deckbrew.xyz/plugins)"
version="$(jq -r --arg n "$store_name" '.[] | select(.name == $n) | .versions[0].name' <<<"$data")"
hash="$(jq -r --arg n "$store_name" '.[] | select(.name == $n) | .versions[0].hash' <<<"$data")"

if [[ -z $version || $version == null || -z $hash || $hash == null ]]; then
  echo "no store entry for '$store_name'" >&2
  exit 1
fi

# Rewrite only the version/hash lines inside this plugin's mkStorePlugin block
# (located by its unique pname).
awk -v p="$pname" -v v="$version" -v h="$hash" '
  index($0, "pname = \"" p "\";") { blk = 1 }
  blk && /version = "/ { sub(/version = "[^"]*"/, "version = \"" v "\"") }
  blk && /hash = "/ { sub(/hash = "[^"]*"/, "hash = \"" h "\""); blk = 0 }
  { print }
' "$default_nix" >"$default_nix.new"
mv "$default_nix.new" "$default_nix"

echo "$pname -> $version"
