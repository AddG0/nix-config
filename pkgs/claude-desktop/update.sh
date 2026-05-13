#!/usr/bin/env bash
# Updates pkgs/claude-desktop/default.nix to the latest claude-desktop-debian
# release. Tags use the dual-version format `v<wrapperVersion>+claude<claudeVersion>`
# and the .deb asset embeds both, so nix-update can't infer either on its own.
set -euo pipefail

FLAKE_ROOT=$(git rev-parse --show-toplevel)
DEFAULT_NIX="$FLAKE_ROOT/pkgs/claude-desktop/default.nix"

tag=$(curl -sfL "https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest" |
	jq -r '.tag_name')

re='^v([0-9]+\.[0-9]+\.[0-9]+)\+claude([0-9]+\.[0-9]+\.[0-9]+)$'
[[ $tag =~ $re ]] || {
	echo "claude-desktop: failed to parse tag '$tag'" >&2
	exit 1
}
new_wrapper="${BASH_REMATCH[1]}"
new_claude="${BASH_REMATCH[2]}"

cur_claude=$(sed -nE 's/^  version = "([^"]+)";/\1/p' "$DEFAULT_NIX")
cur_wrapper=$(sed -nE 's/^  wrapperVersion = "([^"]+)";/\1/p' "$DEFAULT_NIX")

if [[ $cur_claude == "$new_claude" && $cur_wrapper == "$new_wrapper" ]]; then
	echo "claude-desktop: already at $new_claude (wrapper $new_wrapper)"
	exit 0
fi

echo "claude-desktop: $cur_claude/$cur_wrapper -> $new_claude/$new_wrapper"

url="https://github.com/aaddrick/claude-desktop-debian/releases/download/v${new_wrapper}%2Bclaude${new_claude}/claude-desktop_${new_claude}-${new_wrapper}_amd64.deb"
raw=$(nix-prefetch-url "$url" --type sha256)
sri=$(nix hash convert --hash-algo sha256 --to sri "$raw")

sed -i \
	-e "s|^  version = \".*\";|  version = \"$new_claude\";|" \
	-e "s|^  wrapperVersion = \".*\";|  wrapperVersion = \"$new_wrapper\";|" \
	-e "s|hash = \"sha256-[^\"]*\";|hash = \"$sri\";|" \
	"$DEFAULT_NIX"
