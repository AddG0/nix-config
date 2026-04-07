#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#nix-update nixpkgs#jq nixpkgs#parallel --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$FLAKE_DIR/.update-logs"

source "$SCRIPT_DIR/helpers.sh"

# Discover packages as "name:version_policy:has_update_script" lines.
# Packages without a version attr or with nixUpdate.version = "skip" get "skip".
discover_packages() {
  local system
  system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"
  nix eval "$FLAKE_DIR#packages.$system" --apply '
    pkgs: builtins.mapAttrs (name: pkg: {
      version = if !(pkg ? version) then "skip"
        else (pkg.passthru.nixUpdate or {}).version or "stable";
      hasUpdateScript = (pkg.passthru or {}) ? updateScript;
    }) pkgs
  ' --json | jq -r 'to_entries[] | "\(.key):\(.value.version):\(.value.hasUpdateScript)"'
}

export -f log_info log_error log_debug
export DEBUG_MODE FLAKE_DIR LOG_DIR RED GREEN YELLOW BLUE NC

update_one() {
  local pkg_name="${1%%:*}" rest="${1#*:}"
  local version_policy="${rest%%:*}" has_update_script="${rest#*:}"
  local log_file="$LOG_DIR/$pkg_name.log"

  [[ "$version_policy" == "skip" ]] && return 0

  {
    echo "=== $pkg_name ($version_policy) === $(date '+%Y-%m-%d %H:%M:%S')"
    if [[ "$has_update_script" == "true" ]]; then
      nix-update --flake "$pkg_name" --use-update-script 2>&1
    else
      nix-update --flake "$pkg_name" "--version=$version_policy" 2>&1
    fi
  } > "$log_file" 2>&1 && {
    local after_file="$LOG_DIR/snapshots/$pkg_name.after"
    local pkg_dir="$FLAKE_DIR/pkgs/$pkg_name"
    if [[ -d "$pkg_dir" ]]; then
      find "$pkg_dir" -type f -print0 | sort -z | xargs -0 md5sum 2>/dev/null > "$after_file" || true
    else
      : > "$after_file"
    fi
    if diff -q "$LOG_DIR/snapshots/$pkg_name.before" "$after_file" >/dev/null 2>&1; then
      log_info "$pkg_name - already up-to-date"
    else
      log_info "$pkg_name - updated"
    fi
  } || {
    cp "$log_file" "$LOG_DIR/failed/$pkg_name.log"
    log_error "$pkg_name - failed (see .update-logs/failed/$pkg_name.log)"
    return 1
  }
}
export -f update_one

JOBS=10
while getopts "vj:" opt; do
  case "$opt" in
  v) DEBUG_MODE=true ;;
  j) JOBS="$OPTARG" ;;
  *) echo "Usage: $(basename "$0") [-v] [-j N] [package...]"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -gt 0 ]; then
  entries=("${@/%/:stable:false}")
else
  log_info "Discovering packages from flake..."
  mapfile -t entries < <(discover_packages)
  log_info "Found ${#entries[@]} packages"
fi

# Split into updatable and skipped
to_update=()
skipped=0
skipped_names=()
for entry in "${entries[@]}"; do
  rest="${entry#*:}"
  if [[ "${rest%%:*}" == "skip" ]]; then
    ((skipped++)) || true
    skipped_names+=("${entry%%:*}")
  else
    to_update+=("$entry")
  fi
done

if [[ $skipped -gt 0 ]]; then
  log_info "Skipped $skipped packages: ${skipped_names[*]}"
fi
[[ ${#to_update[@]} -eq 0 ]] && { log_info "Nothing to update"; exit 0; }

rm -rf "$LOG_DIR" && mkdir -p "$LOG_DIR/failed" "$LOG_DIR/snapshots"

# Snapshot file hashes before updating so we can detect real changes
for entry in "${to_update[@]}"; do
  pkg="${entry%%:*}"
  pkg_dir="$FLAKE_DIR/pkgs/$pkg"
  if [[ -d "$pkg_dir" ]]; then
    find "$pkg_dir" -type f -print0 | sort -z | xargs -0 md5sum 2>/dev/null > "$LOG_DIR/snapshots/$pkg.before" || true
  else
    : > "$LOG_DIR/snapshots/$pkg.before"
  fi
done

log_info "Updating ${#to_update[@]} packages with $JOBS parallel jobs..."
printf '%s\n' "${to_update[@]}" | parallel --halt never --line-buffer -j "$JOBS" update_one {}

# Summary
failed_count=$(find "$LOG_DIR/failed" -name '*.log' | wc -l)
changed_count=0
for entry in "${to_update[@]}"; do
  pkg="${entry%%:*}"
  [[ -f "$LOG_DIR/failed/$pkg.log" ]] && continue
  after_file="$LOG_DIR/snapshots/$pkg.after"
  if [[ -f "$after_file" ]] && ! diff -q "$LOG_DIR/snapshots/$pkg.before" "$after_file" >/dev/null 2>&1; then
    ((changed_count++)) || true
  fi
done
unchanged_count=$(( ${#to_update[@]} - failed_count - changed_count ))
echo ""
log_info "Results: $changed_count updated, $unchanged_count unchanged, $failed_count failed, $skipped skipped"

if [ "$failed_count" -gt 0 ]; then
  log_warning "Failed packages:"
  for f in "$LOG_DIR/failed"/*.log; do
    echo "  - $(basename "$f" .log)"
  done
  log_info "Review: cat .update-logs/failed/<package>.log"
fi
