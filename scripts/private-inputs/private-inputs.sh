#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#gnugrep nixpkgs#gnused --command bash
# shellcheck shell=bash
#
# Lists the repos a host's build fetches over SSH: the private inputs a machine without SSH access cannot fetch.
# Evaluates the host's system from this checkout without building it.
#
# Usage: scripts/private-inputs/private-inputs.sh <host>
set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
host="${1:?usage: private-inputs.sh <host>}"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! nix eval --debug --raw "$FLAKE_DIR#nixosConfigurations.$host.config.system.build.toplevel.drvPath" >/dev/null 2>"$log"; then
  # git's own reason for a failed fetch comes before nix's error block.
  reason=$({
    sed -n '/^error:/q; /^\(ssh\|fatal\): \|: Permission denied/p' "$log" | sort -u
    sed -n '/^error:/,$p' "$log"
  })
  echo "Evaluating $host's system failed:" >&2
  echo "${reason:-$(tail -n 20 "$log")}" >&2
  exit 1
fi

# Nix logs "using input '<url>' in '<store path>'" for every input the eval reads, even one already in the store.
if ! grep -q "^using input '" "$log"; then
  echo "Nix logged no \"using input\" line while evaluating $host; its --debug wording may have changed." >&2
  exit 1
fi
repos=$(sed -n "s/^using input 'git+\(ssh:\/\/[^?']*\).*/  \1/p" "$log" | sort -u)

if [ -z "$repos" ]; then
  echo "$host's build fetches nothing over SSH."
  exit 0
fi

echo "$host's build fetches these repos over SSH:"
echo "$repos"
