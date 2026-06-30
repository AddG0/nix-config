#!/usr/bin/env bash
# Updates pkgs/kotlin-lsp/default.nix to the latest kotlin-lsp standalone build.
#
# JetBrains tags many versions on GitHub (kotlin-lsp/v<VERSION>) but only
# publishes a subset as downloadable archives on the JetBrains CDN. nix-update
# blindly bumps to the newest tag, which routinely has no CDN artifact and 404s.
# Instead, walk tags newest-first and pick the first one whose archive actually
# exists on the CDN.
set -euo pipefail

FLAKE_ROOT=$(git rev-parse --show-toplevel)
DEFAULT_NIX="$FLAKE_ROOT/pkgs/kotlin-lsp/default.nix"
CDN="https://download-cdn.jetbrains.com/kotlin-lsp"

tags=$(
  curl -sfL "https://api.github.com/repos/Kotlin/kotlin-lsp/tags?per_page=100" |
    grep -oE 'kotlin-lsp/v[0-9]+\.[0-9]+\.[0-9]+' |
    sed 's|kotlin-lsp/v||' |
    sort -urV
)

if [[ -z $tags ]]; then
  echo "kotlin-lsp: no candidate tags found" >&2
  exit 1
fi

new_version=""
for v in $tags; do
  if curl -sfI "$CDN/$v/kotlin-server-$v.tar.gz" >/dev/null 2>&1; then
    new_version="$v"
    break
  fi
done

if [[ -z $new_version ]]; then
  echo "kotlin-lsp: no tag has a published CDN artifact" >&2
  exit 1
fi

cur_version=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$DEFAULT_NIX")

if [[ $cur_version == "$new_version" ]]; then
  echo "kotlin-lsp: already at $new_version"
  exit 0
fi

echo "kotlin-lsp: $cur_version -> $new_version"

raw=$(nix-prefetch-url --unpack --type sha256 "$CDN/$new_version/kotlin-server-$new_version.tar.gz")
sri=$(nix hash convert --hash-algo sha256 --to sri "$raw")

sed -i \
  -e "s|^  version = \".*\";|  version = \"$new_version\";|" \
  -e "s|hash = \"sha256-[^\"]*\";|hash = \"$sri\";|" \
  "$DEFAULT_NIX"
