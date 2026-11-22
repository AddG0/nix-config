#!/usr/bin/env bash
# Manage the packwiz modpacks under home/common/optional/gaming/minecraft/modpacks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MODPACKS_DIR="${MODPACKS_DIR:-$REPO_DIR/home/common/optional/gaming/minecraft/modpacks}"
MODRINTH_API="https://api.modrinth.com/v2"
MODRINTH_USER_AGENT="User-Agent: nix-config-modpack/1.0"
# Modrinth requests in flight at once; more trips its rate limit.
MODRINTH_PARALLEL=10
GREEN=$'\033[32m'
RED=$'\033[31m'
RESET=$'\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  update <modpack> <mod>              Update a specific mod
  update-all <modpack>                Update all mods
  add <modpack> <mod>                 Add a mod from Modrinth
  remove <modpack> <mod>              Remove a mod
  refresh <modpack>                   Refresh packwiz index
  serve <modpack>                     Start packwiz dev server
  list                                List all modpacks
  compat <modpack> <mc-version>       Check mod compatibility for a Minecraft version
  upgrade-target <modpack>            Find the newest Minecraft version every mod supports

Examples:
  $(basename "$0") update main-1.21.11 sodium
  $(basename "$0") add main-1.21.11 "performance mod"
  $(basename "$0") compat main-1.21.11 26.2
EOF
  exit 1
}

require_modpack() {
  local modpack="$1"
  if [ ! -d "$MODPACKS_DIR/$modpack" ]; then
    echo "Error: Modpack '$modpack' not found in $MODPACKS_DIR" >&2
    exit 1
  fi
}

# Runs packwiz inside a modpack's directory.
packwiz_in() {
  local modpack="$1"
  shift
  require_modpack "$modpack"
  (cd "$MODPACKS_DIR/$modpack" && packwiz "$@")
}

# Prints the first `key = "value"` in a packwiz TOML file.
pw_field() {
  local file="$1" key="$2"
  sed -n "s/^$key *= *\"\\(.*\\)\"/\\1/p" "$file" | head -1
}

pack_mc_version() {
  pw_field "$MODPACKS_DIR/$1/pack.toml" minecraft
}

pack_loader() {
  local pack_toml="$MODPACKS_DIR/$1/pack.toml" loader
  for loader in fabric quilt forge neoforge; do
    if [ -n "$(pw_field "$pack_toml" "$loader")" ]; then
      echo "$loader"
      return
    fi
  done
  echo "Error: no fabric/quilt/forge/neoforge version in $pack_toml" >&2
  exit 1
}

modrinth_get() {
  curl -sf --retry 2 --retry-delay 1 -H "$MODRINTH_USER_AGENT" "$MODRINTH_API/$1"
}

# Writes Minecraft release versions, newest first; Modrinth's order handles 1.21.x and 26.x alike.
fetch_releases() {
  if ! modrinth_get tag/game_version |
    jq -r '.[] | select(.version_type == "release") | .version' >"$1"; then
    echo "Error: could not fetch Minecraft releases from Modrinth" >&2
    exit 1
  fi
}

# For every mod in the pack, writes <outdir>/<mod-id>.name and <mod-id>.versions
# (the Minecraft versions it has builds for on the pack's loader). Exits on any failure.
fetch_mod_versions() {
  local modpack="$1" outdir="$2" loader toml mod_id count=0
  loader=$(pack_loader "$modpack")
  for toml in "$MODPACKS_DIR/$modpack/mods"/*.pw.toml; do
    mod_id=$(pw_field "$toml" mod-id)
    if [ -z "$mod_id" ]; then
      echo "Error: $(basename "$toml") has no Modrinth mod-id; can't check it" >&2
      exit 1
    fi
    (
      mod_name=$(pw_field "$toml" name)
      if ! modrinth_get "project/$mod_id/version?loaders=%5B%22$loader%22%5D" |
        jq -r '[.[].game_versions[]] | unique | .[]' >"$outdir/$mod_id.versions"; then
        echo "Error: Modrinth request failed for $mod_name ($mod_id)" >&2
        exit 1
      fi
      echo "$mod_name" >"$outdir/$mod_id.name"
    ) &
    count=$((count + 1))
    [ $((count % MODRINTH_PARALLEL)) -eq 0 ] && wait
  done
  wait
  if [ "$(find "$outdir" -name '*.name' | wc -l)" -ne "$count" ]; then
    echo "Error: some Modrinth lookups failed (see above); result would be wrong" >&2
    exit 1
  fi
}

# Prints the names of mods with no build for a Minecraft version, sorted.
mods_missing() {
  local outdir="$1" mc_version="$2" versions
  for versions in "$outdir"/*.versions; do
    grep -qxF "$mc_version" "$versions" || cat "${versions%.versions}.name"
  done | sort
}

cmd_serve() {
  local modpack="$1"
  echo "Point the instance's pre-launch packwiz installer at http://localhost:8080/pack.toml"
  echo "(the command's form is PreLaunchCommand in modules/home/prismlauncher/default.nix)."
  echo "Starting packwiz serve... (Ctrl+C to stop)"
  echo ""
  packwiz_in "$modpack" serve
}

cmd_list() {
  find "$MODPACKS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

cmd_compat() {
  local modpack="$1" mc_version="$2"
  require_modpack "$modpack"
  local workdir
  workdir=$(mktemp -d)
  trap 'rm -rf "'"$workdir"'"' EXIT

  echo "Checking mod compatibility for Minecraft $mc_version..."
  fetch_releases "$workdir/releases"
  fetch_mod_versions "$modpack" "$workdir"

  local versions mod_name newest supported=0
  local -a missing=()
  for versions in "$workdir"/*.versions; do
    mod_name=$(cat "${versions%.versions}.name")
    if grep -qxF "$mc_version" "$versions"; then
      supported=$((supported + 1))
    else
      newest=$(grep -xF -f "$versions" "$workdir/releases" | head -1)
      missing+=("$mod_name|${newest:-none}")
    fi
  done

  echo ""
  if [ ${#missing[@]} -eq 0 ]; then
    echo "All $supported mods support $mc_version!"
    return
  fi
  echo "=== NOT SUPPORTED ($mc_version) ==="
  local entry
  while IFS= read -r entry; do
    printf "  ${RED}✗${RESET} %-40s (newest release supported: %s)\n" "${entry%%|*}" "${entry#*|}"
  done < <(printf '%s\n' "${missing[@]}" | sort)
  echo ""
  echo "Summary: $supported supported, ${#missing[@]} unsupported"
}

cmd_upgrade_target() {
  local modpack="$1"
  require_modpack "$modpack"
  local workdir
  workdir=$(mktemp -d)
  trap 'rm -rf "'"$workdir"'"' EXIT

  echo "Fetching $(pack_loader "$modpack") versions for every mod in $modpack..."
  fetch_releases "$workdir/releases"
  fetch_mod_versions "$modpack" "$workdir"
  local mod_count
  mod_count=$(find "$workdir" -name '*.name' | wc -l)

  local current
  current=$(pack_mc_version "$modpack")
  local target="" mc_version missing
  local -a blocked=()
  while read -r mc_version; do
    # Mods are known to run on the pack's own version even when not tagged for it.
    [ "$mc_version" = "$current" ] && break
    missing=$(mods_missing "$workdir" "$mc_version")
    if [ -z "$missing" ]; then
      target="$mc_version"
      break
    fi
    blocked+=("$mc_version|$missing")
  done <"$workdir/releases"

  if [ -z "$target" ]; then
    echo -e "\nNo release newer than $current is supported by all $mod_count mods; stay on $GREEN$current$RESET."
  else
    echo -e "\nNewest version all $mod_count mods support: $GREEN$target$RESET (pack is on $current)"
  fi
  [ ${#blocked[@]} -eq 0 ] && return
  echo -e "\nBlockers for releases newer than ${target:-$current}:"
  local entry
  for entry in "${blocked[@]}"; do
    mc_version="${entry%%|*}"
    missing="${entry#*|}"
    echo -e "\n  $mc_version — $(wc -l <<<"$missing") missing:"
    local mod_name
    while IFS= read -r mod_name; do
      printf "    ${RED}✗${RESET} %s\n" "$mod_name"
    done <<<"$missing"
  done
}

[ $# -lt 1 ] && usage

case "$1" in
update)
  [ $# -lt 3 ] && usage
  packwiz_in "$2" update "$3" -y
  ;;
update-all)
  [ $# -lt 2 ] && usage
  packwiz_in "$2" update --all -y
  ;;
add)
  [ $# -lt 3 ] && usage
  packwiz_in "$2" modrinth add "$3"
  ;;
remove)
  [ $# -lt 3 ] && usage
  packwiz_in "$2" remove "$3"
  ;;
refresh)
  [ $# -lt 2 ] && usage
  packwiz_in "$2" refresh
  ;;
serve)
  [ $# -lt 2 ] && usage
  cmd_serve "$2"
  ;;
list)
  cmd_list
  ;;
compat)
  [ $# -lt 3 ] && usage
  cmd_compat "$2" "$3"
  ;;
upgrade-target)
  [ $# -lt 2 ] && usage
  cmd_upgrade_target "$2"
  ;;
*)
  usage
  ;;
esac
