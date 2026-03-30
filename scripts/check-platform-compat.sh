#!/usr/bin/env bash
# Check which packages in a NixOS system closure would be incompatible with a given platform.
# Two-phase approach:
#   1. Get every package name from the full system closure via nix path-info -r
#   2. Look each one up in nixpkgs and check meta.platforms for the target
#
# Uses temporary files in /tmp — no repo files are modified.
#
# Usage: ./scripts/check-platform-compat.sh <host> [target-platform]
#   host:            NixOS configuration name (required)
#   target-platform: platform to check against (default: aarch64-linux)

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $(basename "$0") <host> [target-platform]"
  echo "  host:            NixOS configuration name (required)"
  echo "  target-platform: platform to check against (default: aarch64-linux)"
  exit 1
fi

HOST="$1"
TARGET="${2:-aarch64-linux}"
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMPDIR=$(mktemp -d /tmp/check-compat-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

echo ""
echo "  Checking $HOST → $TARGET"
echo "  ─────────────────────────────────────"
echo ""

# Phase 1
echo "  [1/3] Evaluating system.build.toplevel..."
TOPLEVEL=$(nix eval "${FLAKE_DIR}#nixosConfigurations.${HOST}.config.system.build.toplevel" --raw 2>/dev/null)

echo "  [2/3] Querying full closure..."
nix path-info -r "$TOPLEVEL" 2>/dev/null \
  | sed 's|/nix/store/[a-z0-9]*-||' \
  | sort -u \
  | grep -E '^[a-zA-Z].*-[0-9]+' \
  | grep -v '\.patch$\|\.conf$\|\.sh$\|\.lua\|\.service\|\.mount\|\.socket\|\.timer\|\.target\|\.path$' \
  | grep -v -- '-doc$\|-man$\|-dev$\|-bin$\|-lib$\|-info$' \
  > "$TMPDIR/packages.txt"

PKG_COUNT=$(wc -l < "$TMPDIR/packages.txt")
echo "         $PKG_COUNT package paths found"

# Phase 2
echo "  [3/3] Checking meta.platforms for each package..."

cat > "$TMPDIR/check.nix" << NIXEOF
let
  rawNames = builtins.filter (n: n != "" && builtins.isString n)
    (builtins.split "\n" (builtins.readFile ./packages.txt));

  pkgs = (builtins.getFlake "${FLAKE_DIR}").inputs.nixpkgs.legacyPackages.x86_64-linux;
  lib = pkgs.lib;

  target = lib.systems.elaborate "${TARGET}";

  stripVersion = name:
    let
      m = builtins.match "^([a-zA-Z][a-zA-Z0-9_+]*(-[a-zA-Z][a-zA-Z0-9_+]*)*)-[0-9].*" name;
    in if m != null then builtins.head m else name;

  stripWrapperSuffix = name:
    let
      m = builtins.match "^(.*[0-9][0-9.]*)(-bwrap|-fhsenv-profile|-fhsenv-rootfs|-init|-unwrapped)$" name;
    in if m != null then builtins.head m else name;

  platformMatches = plat:
    if builtins.isString plat then plat == "${TARGET}"
    else if builtins.isAttrs plat then
      (builtins.tryEval (lib.meta.platformMatch target plat)).value or false
    else false;

  summarizePlatforms = platforms:
    let
      stringPlats = builtins.filter (p: p != null)
        (map (p: if builtins.isString p then p else null) platforms);
    in
      if builtins.length stringPlats <= 4 then stringPlats
      else lib.take 3 stringPlats ++ ["..."];

  tryLookup = storeName:
    let
      attrName = stripVersion storeName;
      exists = pkgs ? \${attrName};
      evalResult =
        if !exists then { success = true; value = { found = false; compatible = null; summary = []; }; }
        else builtins.tryEval (
          let
            pkg = pkgs.\${attrName};
            meta = builtins.deepSeq (pkg.name or "") (pkg.meta or {});
            platforms = meta.platforms or [];
            compat = if platforms == [] then true
                     else builtins.deepSeq platforms (builtins.any platformMatches platforms);
            summary = if compat then [] else builtins.deepSeq platforms (summarizePlatforms platforms);
          in builtins.deepSeq compat {
            found = true;
            compatible = compat;
            inherit summary;
          }
        );
    in {
      name = storeName;
      baseName = stripWrapperSuffix storeName;
      attr = attrName;
      found = if evalResult.success then evalResult.value.found else false;
      isCompatible = if evalResult.success then evalResult.value.compatible else null;
      summary = if evalResult.success then evalResult.value.summary or [] else [];
    };

  results = map tryLookup rawNames;
  found = builtins.filter (r: r.found) results;
  notFound = builtins.filter (r: !r.found) results;
  incompatible = builtins.filter (r: r.isCompatible == false) found;
  compatible = builtins.filter (r: r.isCompatible == true) found;

in {
  summary = {
    total = builtins.length rawNames;
    resolved = builtins.length found;
    unresolved = builtins.length notFound;
    compatible = builtins.length compatible;
    incompatible = builtins.length incompatible;
  };
  incompatibleGrouped =
    let
      seen = builtins.foldl' (acc: r:
        if acc ? \${r.baseName} then acc
        else acc // { \${r.baseName} = { name = r.baseName; summary = r.summary; attr = r.attr; }; }
      ) {} incompatible;
      entries = builtins.attrValues seen;
    in lib.sort (a: b: a.name < b.name) entries;
  unresolvedNames = lib.sort (a: b: a < b) (lib.unique (map (r: r.name) notFound));
}
NIXEOF

RESULT=$(nix eval --json --file "$TMPDIR/check.nix" 2>/dev/null)

echo ""
echo "$RESULT" | jq -r '
  .summary as $s |

  "  ┌─────────────────────────────────────┐",
  "  │           Summary                   │",
  "  ├─────────────────────────────────────┤",
  "  │  Total paths:       \($s.total | tostring | " " * (14 - (. | length)) + .)  │",
  "  │  Resolved:          \($s.resolved | tostring | " " * (14 - (. | length)) + .)  │",
  "  │  Unresolved:        \($s.unresolved | tostring | " " * (14 - (. | length)) + .)  │",
  "  │                                     │",
  "  │  Compatible:        \($s.compatible | tostring | " " * (14 - (. | length)) + .)  │",
  "  │  Incompatible:      \($s.incompatible | tostring | " " * (14 - (. | length)) + .)  │",
  "  └─────────────────────────────────────┘",
  ""
'

# Incompatible packages
INCOMPAT_COUNT=$(echo "$RESULT" | jq '.incompatibleGrouped | length')
if [[ "$INCOMPAT_COUNT" -gt 0 ]]; then
  echo "  Incompatible Packages"
  echo "  ─────────────────────────────────────"
  echo "$RESULT" | jq -r '
    # Find longest name for alignment
    ([.incompatibleGrouped[].name | length] | max) as $maxlen |
    .incompatibleGrouped[] |
    ($maxlen - (.name | length)) as $pad |
    if (.summary | length) > 0 then
      "  ✗ \(.name)\(" " * ($pad + 2))(\(.summary | join(", ")))"
    else
      "  ✗ \(.name)"
    end
  '
  echo ""
fi

# Unresolved packages
UNRESOLVED_COUNT=$(echo "$RESULT" | jq '.summary.unresolved')
if [[ "$UNRESOLVED_COUNT" -gt 0 ]]; then
  echo "  Unresolved ($UNRESOLVED_COUNT paths not in top-level nixpkgs)"
  echo "  ─────────────────────────────────────"
  SHOWN=30
  echo "$RESULT" | jq -r --argjson shown "$SHOWN" '
    .unresolvedNames[:$shown][] | "  ? \(.)"
  '
  if [[ "$UNRESOLVED_COUNT" -gt "$SHOWN" ]]; then
    REMAINING=$((UNRESOLVED_COUNT - SHOWN))
    echo "  ... and $REMAINING more"
  fi
  echo ""
fi
