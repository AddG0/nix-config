#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#nix-fast-build nixpkgs#nix-output-monitor nixpkgs#jq nixpkgs#gum --command bash
# shellcheck shell=bash
# Builds every package our overlays define or patch, as this host builds it, so a bump's broken patch shows before a rebuild.
# Usage: build-overlaid-packages.sh [overlay-path-filter...]

# Summarises overlaid-packages.nix's output against nix-fast-build's result file; fails unless every target built or was cached.
verdict() {
  local overlaid=$1 results=$2 build_exit=$3
  local rows status attr overlays error passed=0 broken=0

  rows=$(jq -r --slurpfile run "$results" '
    ($run[0].results | group_by(.attr) | map({key: .[0].attr, value: .}) | from_entries) as $byAttr
    | .overlaysByTarget | to_entries[]
    | ($byAttr[.key] // []) as $entries
    | [
        (if $entries == [] then "missing"
         elif any($entries[]; .success == false) then "failed"
         elif any($entries[]; .skipped == true) then "skipped"
         else "ok" end),
        .key,
        (.value | join(", ")),
        # An eval error ends in the message that matters; a build error is one line.
        (first($entries[] | select(.success == false) | .error // "" | split("\n") | map(sub("^\\s+"; "")) | map(select(length > 0))
          | ((map(select(test("^error: ."))) | last) // .[0] // "")) // "")
      ]
    | @tsv' "$overlaid") || {
    echo "✗ cannot read the build results in $results"
    return 1
  }

  while IFS=$'\t' read -r status attr overlays error; do
    case "$status" in
    ok) passed=$((passed + 1)) ;;
    skipped) echo "– $attr: not built on this platform" ;;
    missing)
      broken=$((broken + 1))
      echo "✗ $attr: no build result  <- $overlays"
      ;;
    failed)
      broken=$((broken + 1))
      echo "✗ $attr  <- $overlays"
      [ -z "$error" ] || echo "    $error"
      ;;
    esac
  done <<<"$rows"

  echo "✓ $passed built or cached"
  jq -r '.nonPackageAttrPaths[] | "nothing to build: \(.)"' "$overlaid"
  jq -r 'select(.overlaysSettingNothing != []) | "sets nothing itself here: \(.overlaysSettingNothing | join(", "))"' "$overlaid"

  if [ "$broken" -eq 0 ] && [ "$build_exit" -ne 0 ]; then
    echo "✗ nix-fast-build exited $build_exit without a failed target"
    return 1
  fi
  [ "$broken" -eq 0 ]
}

main() {
  set -euo pipefail
  local flake_dir host configurations tmp build_exit summary

  flake_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  host="$(hostname -s)"
  case "$(uname -s)" in
  Darwin) configurations=darwinConfigurations ;;
  *) configurations=nixosConfigurations ;;
  esac

  tmp=$(mktemp -d /tmp/build-overlaid-packages-XXXXXX)
  # shellcheck disable=SC2064 # expand now: $tmp is local to main.
  trap "rm -rf '$tmp'" EXIT
  # Let nix-fast-build (foreground) catch SIGINT and stop every job; just flag it.
  interrupted=0
  trap 'interrupted=1' INT

  jq -n '$ARGS.positional' --args "$@" >"$tmp/filters.json"
  cat >"$tmp/overlaid.nix" <<EOF
let
  flake = builtins.getFlake "$flake_dir";
  config = flake.$configurations."$host" or (throw "no $configurations.$host in $flake_dir; run this on a host the flake configures");
in
  import "\${flake}/overlays/overlaid-packages.nix" {inherit (flake.inputs.nixpkgs) lib;} {
    inherit (flake) inputs;
    inherit (config) pkgs;
    filters = builtins.fromJSON (builtins.readFile $tmp/filters.json);
  }
EOF
  echo "(import $tmp/overlaid.nix).targets" >"$tmp/targets.nix"

  nix eval --impure --json --file "$tmp/overlaid.nix" \
    --apply 'r: {inherit (r) overlaysByTarget nonPackageAttrPaths overlaysSettingNothing;}' >"$tmp/overlaid.json"
  if jq -e '[.overlaysByTarget, .nonPackageAttrPaths, .overlaysSettingNothing] | all(length == 0)' "$tmp/overlaid.json" >/dev/null; then
    echo "no overlay path matches: $*"
    return 1
  fi
  if jq -e '.overlaysByTarget | length == 0' "$tmp/overlaid.json" >/dev/null; then
    echo "nothing to build in the overlays matching: $*"
    jq -r '.nonPackageAttrPaths[], .overlaysSettingNothing[]' "$tmp/overlaid.json"
    return 0
  fi
  gum log --level info "building $(jq '.overlaysByTarget | length' "$tmp/overlaid.json") overlaid packages as $host builds them"

  set +e
  # One eval worker per CPU at ~2 GiB each would exhaust memory; 4 keeps evaluation ahead of the builds.
  nix-fast-build --file "$tmp/targets.nix" --impure --skip-cached --skip-unsupported --eval-workers 4 \
    --result-file "$tmp/result.json"
  build_exit=$?
  set -e

  if [ "$interrupted" -eq 1 ]; then
    echo
    echo "aborted"
    return 130
  fi
  if [ ! -f "$tmp/result.json" ]; then
    echo "nix-fast-build exited $build_exit without writing $tmp/result.json"
    return 1
  fi

  if summary=$(verdict "$tmp/overlaid.json" "$tmp/result.json" "$build_exit"); then
    gum style --border rounded --border-foreground 240 --padding "0 1" --margin "1 0" "$summary"
  else
    gum style --border rounded --border-foreground 1 --padding "0 1" --margin "1 0" "$summary"
    return 1
  fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
