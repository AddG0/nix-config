#!/usr/bin/env bash
# Updates pkgs/kotlin-lsp/default.nix to the latest kotlin-lsp standalone build,
# for both published Linux architectures (x86_64, aarch64).
#
# JetBrains tags many versions on GitHub (kotlin-lsp/v<VERSION>) but only
# publishes a subset as downloadable archives on the JetBrains CDN. nix-update
# blindly bumps to the newest tag, which routinely has no CDN artifact and 404s.
# Instead, walk tags newest-first and pick the first one with both arch archives
# published.
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
  if curl -sfI "$CDN/$v/kotlin-server-$v.tar.gz" >/dev/null 2>&1 &&
    curl -sfI "$CDN/$v/kotlin-server-$v-aarch64.tar.gz" >/dev/null 2>&1; then
    new_version="$v"
    break
  fi
done

if [[ -z $new_version ]]; then
  echo "kotlin-lsp: no tag has published CDN artifacts for both architectures" >&2
  exit 1
fi

cur_version=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$DEFAULT_NIX")

if [[ $cur_version == "$new_version" ]]; then
  echo "kotlin-lsp: already at $new_version"
  exit 0
fi

echo "kotlin-lsp: $cur_version -> $new_version"

sri_for() {
  local raw
  raw=$(nix-prefetch-url --unpack --type sha256 "$1")
  nix hash convert --hash-algo sha256 --to sri "$raw"
}

x86_64_sri=$(sri_for "$CDN/$new_version/kotlin-server-$new_version.tar.gz")
aarch64_sri=$(sri_for "$CDN/$new_version/kotlin-server-$new_version-aarch64.tar.gz")

sed -i "s|^  version = \".*\";|  version = \"$new_version\";|" "$DEFAULT_NIX"

# Each arch's hash line is matched by the distinct `suffix` line right above it,
# since both otherwise share the same `hash = "sha256-...";` shape.
perl -0777 -pi -e "s/(suffix = \"\";\\s*\\n\\s*hash = \")sha256-[^\"]*(\";)/\${1}$x86_64_sri\${2}/" "$DEFAULT_NIX"
perl -0777 -pi -e "s/(suffix = \"-aarch64\";\\s*\\n\\s*hash = \")sha256-[^\"]*(\";)/\${1}$aarch64_sri\${2}/" "$DEFAULT_NIX"
