#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#jq --command bash
# shellcheck shell=bash
#
# List every importable optional module (lib.custom.optional) with the suites it
# belongs to, then every suite (lib.custom.suites) and its nixos/home halves.
# Evaluates only the flake's lib, never a host.
#
# Usage: scripts/list-optional.sh [filter]   # filter by prefix, e.g. home.development
set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
filter="${1:-}"
# Colour only on a terminal, and never when NO_COLOR is set.
color=0
[[ -t 1 && -z ${NO_COLOR:-} ]] && color=1

# shellcheck disable=SC2016 # ${...} below is Nix interpolation, not shell.
expr='
  let
    lib = (builtins.getFlake (toString FLAKE)).lib;
    flatten = pre: tree:
      lib.concatMapAttrs (n: v:
        if builtins.isAttrs v
        then flatten "${pre}${n}." v
        else {"${pre}${n}" = toString v;})
      tree;
  in {
    leaves = lib.concatMapAttrs (root: tree: flatten "${root}." tree) lib.custom.optional;
    suites = lib.mapAttrs (_: lib.mapAttrs (_: map toString)) lib.custom.suites;
  }'

nix eval --json --impure --expr "${expr//FLAKE/\"$FLAKE_DIR\"}" |
  jq -r --arg filter "$filter" --arg color "$color" -f "$(dirname "${BASH_SOURCE[0]}")/list-optional.jq"
