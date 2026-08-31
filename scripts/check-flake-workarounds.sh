#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix-fast-build jq nix-output-monitor gum
# shellcheck shell=bash
#
# Check whether the flake-update workarounds are still needed.
#
# For each *.nix in overlays/flake-update-workarounds, this builds its target
# package (declared with a `# CHECK-ATTR: <attrpath>` line) against the flake's
# *pinned* nixpkgs with NO overlays applied — i.e. plain upstream. All targets
# build in parallel. If a target builds, upstream is fine on the current pin and
# the workaround is redundant and can be dropped; if it fails, the workaround is
# still doing its job. Redundant ones can be deleted at the end when prompted.
#
# A workaround on a package from a flake input rather than nixpkgs declares
# `# CHECK-FLAKE-ATTR: <input>.<attrpath>` instead — resolved under
# `flake.inputs` with `system` in scope, e.g.
# `wayscriber.packages.${system}.default`. Same verdict, different lookup.
#
# A workaround tagged `# CHECK-RUNTIME: <note>` fixes runtime behavior, not a
# build failure — building it proves nothing, so it is NOT built and is always
# reported as NEEDS MANUAL CHECK with its note.
#
# Uses temporary files in /tmp — no repo files are modified (except deletions you
# confirm at the prompt).
#
# Usage: ./scripts/check-flake-workarounds.sh            # check every workaround
#        ./scripts/check-flake-workarounds.sh gdal pdal  # only files matching names
set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKAROUNDS_DIR="$FLAKE_DIR/overlays/flake-update-workarounds"

TMPDIR=$(mktemp -d /tmp/check-workarounds-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT
# Let nix-fast-build (foreground) catch SIGINT and stop every job; just flag it.
interrupted=0
trap 'interrupted=1' INT

red=$'\e[31m'
grn=$'\e[32m'
ylw=$'\e[33m'
dim=$'\e[2m'
rst=$'\e[0m'

files=()
for f in "$WORKAROUNDS_DIR"/*.nix; do
  [ -e "$f" ] || continue
  if [ "$#" -gt 0 ]; then
    match=0
    for pat in "$@"; do [[ "$(basename "$f")" == *"$pat"* ]] && match=1; done
    [ "$match" -eq 1 ] || continue
  fi
  files+=("$f")
done
[ "${#files[@]}" -gt 0 ] || {
  echo "no matching workarounds"
  exit 0
}

# Build the CHECK-ATTR targets as one attrset from the flake's pinned nixpkgs;
# config mirrors pkgs/flake-module.nix, impure for getFlake + currentSystem.
declare -A runtime
buildable=()
manual=()
expr_file="$TMPDIR/targets.nix"
{
  echo 'let'
  echo "  flake = builtins.getFlake \"$FLAKE_DIR\";"
  echo '  system = builtins.currentSystem;'
  echo '  pkgs = import flake.inputs.nixpkgs {'
  echo '    inherit system;'
  echo '    config = { allowUnfree = true; permittedInsecurePackages = ["openssl-1.1.1w"]; };'
  echo '  };'
  echo 'in {'
  for f in "${files[@]}"; do
    name="$(basename "$f" .nix)"
    note="$(sed -n 's/^# *CHECK-RUNTIME: *//p' "$f" | head -n1)"
    if [ -n "$note" ]; then
      runtime["$name"]="$note"
      manual+=("$name")
      continue
    fi
    flakeAttr="$(sed -n 's/^# *CHECK-FLAKE-ATTR: *//p' "$f" | head -n1)"
    if [ -n "$flakeAttr" ]; then
      buildable+=("$name")
      printf '  "%s" = flake.inputs.%s;\n' "$name" "$flakeAttr"
      continue
    fi
    attr="$(sed -n 's/^# *CHECK-ATTR: *//p' "$f" | head -n1)"
    if [ -z "$attr" ]; then
      printf '%s??  %-40s no CHECK-ATTR line — skipped%s\n' "$ylw" "$name" "$rst" >&2
      continue
    fi
    buildable+=("$name")
    printf '  "%s" = pkgs.%s;\n' "$name" "$attr"
  done
  echo '}'
} >"$expr_file"

redundant=()
needed=()
if [ "${#buildable[@]}" -gt 0 ]; then
  res="$TMPDIR/result.json"
  set +e
  nix-fast-build --file "$expr_file" --impure --skip-cached --result-file "$res"
  rc=$?
  set -e

  if [ "$interrupted" -eq 1 ]; then
    echo
    echo "${ylw}aborted${rst}"
    exit 130
  fi
  [ -f "$res" ] || {
    echo "${red}nix-fast-build produced no result (exit $rc)${rst}"
    exit "$rc"
  }

  # Cached or freshly built = REDUNDANT; any failing result = still NEEDED.
  failed="$(jq -r '.results[] | select(.success == false) | .attr' "$res" | sort -u)"
  for name in "${buildable[@]}"; do
    if grep -qxF "$name" <<<"$failed"; then
      needed+=("$name")
    else
      redundant+=("$name")
    fi
  done
fi

summary=$(
  printf '%s✓ redundant (safe to drop):%s %s\n' "$grn" "$rst" "${redundant[*]:-none}"
  printf '%s✗ still needed:%s            %s\n' "$red" "$rst" "${needed[*]:-none}"
  printf '%s? manual runtime check:%s    %s\n' "$ylw" "$rst" "${manual[*]:-none}"
  for name in "${manual[@]:-}"; do
    [ -n "$name" ] || continue
    printf '    %s%s: %s%s\n' "$dim" "$name" "${runtime[$name]}" "$rst"
  done
)
gum style --border rounded --border-foreground 240 --padding "0 1" --margin "1 0" "$summary"

# Offer to delete the workarounds upstream no longer needs.
if [ "${#redundant[@]}" -gt 0 ] && [ -t 0 ]; then
  preselect="${redundant[*]}" # gum --selected wants a comma-separated list
  chosen=$(printf '%s\n' "${redundant[@]}" | gum choose --no-limit \
    --selected "${preselect// /,}" \
    --header "Delete redundant workarounds? (space toggles, enter confirms)") || chosen=""
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    rm -f "$WORKAROUNDS_DIR/$name.nix"
    gum log --level info "deleted $name.nix"
  done <<<"$chosen"
  [ -n "$chosen" ] && echo "Review with: git status"
fi
