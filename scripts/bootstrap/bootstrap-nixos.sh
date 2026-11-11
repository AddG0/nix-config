#!/usr/bin/env bash
# Installs a host from this flake onto a machine booted from the installer stick, run from demon; reruns resume.
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

ssh_port=22
ssh_key=""

function usage() {
  echo
  echo "Installs NixOS from this nix-config onto a machine booted from the installer stick."
  echo
  echo "USAGE: $0 <hostname> <ip> [OPTIONS]"
  echo
  echo "  A new <hostname> gets hosts/nixos/<hostname>/ from scripts/bootstrap/scaffold, either"
  echo "  wiping a disk you pick (disko) or installing onto what is mounted at /mnt."
  echo "  An existing host keeps its own disk layout. A host using sops gets a new host key,"
  echo "  and nix-secrets is re-encrypted to it, committed and pushed before the install."
  echo "  A rerun after a failed install reuses that key and skips what already happened."
  echo
  echo "OPTIONS:"
  echo "  --port <port>   ssh port of the stick. Default: ${ssh_port}."
  echo "  -k <ssh_key>    private key for root on the stick. Default: your agent and ssh config."
  echo "  --debug         trace every command except the passphrase."
  echo "  -h | --help     print this help."
}

function usage_error() {
  red "$1"
  usage
  exit 1
}

function require_tools() {
  local tool
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null; then
      red "$tool is not on PATH."
      exit 1
    fi
  done
}

# Connect

# The stick's host key changes every boot, so it is never recorded.
# Exit 255 is ssh itself failing, not the remote command; callers must not read it as an answer.
function on_target() {
  local opts=(-n -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10) rc=0
  [[ -n $ssh_key ]] && opts+=(-i "$ssh_key")
  ssh "${opts[@]}" "root@$target" "$@" || rc=$?
  [[ $rc -ne 255 ]] || red "Lost the ssh connection to root@$target." >&2
  return "$rc"
}

# Sets stick_disk: the whole disk the stick booted from, whose iso9660 filesystem is /iso.
function connect_to_stick() {
  if ! on_target true; then
    red "Cannot ssh to root@$target:$ssh_port. Boot the target from the installer stick and check its IP with 'ip -br a'."
    exit 1
  fi
  # shellcheck disable=SC2016 # expands on the target
  if ! stick_disk=$(on_target 'src=$(findmnt -no SOURCE /iso) || exit 1
      src=$(readlink -f "$src")
      parent=$(lsblk -no PKNAME "$src" | head -1)
      dev="/dev/${parent:-${src#/dev/}}"
      [ -b "$dev" ] && echo "$dev"') || [[ ! $stick_disk =~ ^/dev/[A-Za-z0-9]+$ ]]; then
    red "root@$target has no installer stick mounted at /iso; refusing to install over a running system."
    exit 1
  fi
}

# Prepare the host

# Prints "<by-id path> <size> <model>" once per whole disk, leaving out the stick.
function list_target_disks() {
  # ssh joins its arguments into one command line, so the stick goes in as text, not as $1.
  # shellcheck disable=SC2016 # expands on the target
  on_target "stick=$stick_disk;"' seen=" "
    for pass in preferred fallback; do
      for id in /dev/disk/by-id/*; do
        case "$id" in *-part* | */dm-* | */lvm-* | */md-*) continue ;; esac
        case "$pass:$id" in preferred:*/wwn-* | preferred:*/nvme-eui.* | preferred:*_1) continue ;; esac
        dev=$(readlink -f "$id")
        case "$seen" in *" $dev "*) continue ;; esac
        [ "$dev" = "$stick" ] && continue
        [ "$(lsblk -dno TYPE "$dev")" = disk ] || continue
        seen="$seen$dev "
        echo "$id $(lsblk -dno SIZE,MODEL "$dev" | xargs)"
      done
    done'
}

# Sets disk_id to the by-id path of a disk on the target you pick.
function pick_disk() {
  local listing disks=() choice=""
  if ! listing=$(list_target_disks); then
    red "Listing disks on $target failed."
    exit 1
  fi
  [[ -n $listing ]] && mapfile -t disks <<<"$listing"
  if [[ ${#disks[@]} -eq 0 ]]; then
    red "No disks found on $target besides the installer stick ($stick_disk)."
    exit 1
  fi
  blue "Disks on $target (the installer stick $stick_disk is not listed):"
  select choice in "${disks[@]}"; do
    [[ -n $choice ]] && break
  done
  if [[ -z $choice ]]; then
    red "No disk chosen."
    exit 1
  fi
  disk_id=${choice%% *}
  if [[ ! $disk_id =~ ^/dev/disk/by-id/[A-Za-z0-9._:-]+$ ]]; then
    red "Unexpected disk id '$disk_id'."
    exit 1
  fi
}

# Writes the target's hardware-configuration.nix for /mnt into $1, replacing it only on success.
function write_hardware_config() {
  local out
  out=$(mktemp)
  if ! on_target nixos-generate-config --root /mnt --show-hardware-config >"$out" || [[ ! -s $out ]]; then
    rm -f "$out"
    red "nixos-generate-config on $target failed; $1 is unchanged."
    exit 1
  fi
  chmod 644 "$out"
  mv "$out" "$1"
  green "Wrote $1 from the target's /mnt"
}

function require_mnt() {
  local mount rc
  for mount in /mnt /mnt/boot; do
    rc=0
    on_target findmnt "$mount" >/dev/null || rc=$?
    [[ $rc -ne 255 ]] || exit 1
    if [[ $rc -ne 0 ]]; then
      red "Nothing mounted at $mount on $target. Partition, format and mount the root at /mnt and the ESP at /mnt/boot first."
      exit 1
    fi
  done
}

# Sets partitioning, and layout when a disk is wiped: the common/disks file the new host imports.
function ask_partitioning() {
  local answer
  echo "  d) wipe a disk with disko (btrfs)"
  echo "  m) install onto what is already mounted at /mnt on the target"
  partitioning=""
  while [[ -z $partitioning ]]; do
    if ! read -rp "Choose d or m: " answer; then
      red "No answer given."
      exit 1
    fi
    case $answer in
    d) partitioning=disko ;;
    m) partitioning=premounted ;;
    esac
  done
  [[ $partitioning == disko ]] || return 0
  layout=""
  while [[ -z $layout ]]; do
    if ! read -rp "Encrypt it with LUKS? [Y/n] " answer; then
      red "No answer given."
      exit 1
    fi
    case $answer in
    "" | y | Y) layout=luks-btrfs ;;
    n | N) layout=btrfs ;;
    esac
  done
}

# Builds a new host from the scaffold in a temp dir, then moves it into place whole.
function scaffold_host() {
  local scaffold="scripts/bootstrap/scaffold"
  blue "$host is a new host."
  ask_partitioning

  staging=$(mktemp -d)
  chmod 755 "$staging"
  cp "$scaffold/host/default.nix" "$staging/default.nix"
  if [[ $partitioning == disko ]]; then
    pick_disk
    sed -e "s|@DISK@|$disk_id|" -e "s|@LAYOUT@|$layout|" "$scaffold/disko.nix" >"$staging/disko.nix"
    green "Generating facter.json on $target"
    if ! on_target nixos-facter >"$staging/facter.json"; then
      red "nixos-facter failed on $target."
      exit 1
    fi
    if ! jq -e .version "$staging/facter.json" >/dev/null; then
      red "nixos-facter on $target did not produce a hardware report:"
      head -c 500 "$staging/facter.json" >&2
      exit 1
    fi
  else
    require_mnt
    write_hardware_config "$staging/hardware-configuration.nix"
  fi
  new_host_dir=$host_dir
  mv "$staging" "$host_dir"
  staging=""
}

# Sets partitioning: disko when the host's layout wipes a disk, premounted when it installs onto /mnt.
function prepare_host() {
  local has_disko
  if [[ ! -d $host_dir ]]; then
    scaffold_host
  elif ! has_disko=$(nix eval --json ".#nixosConfigurations.$host.options" --apply 'o: o ? disko'); then
    red "Could not evaluate .#$host to tell whether it uses disko."
    exit 1
  elif [[ $has_disko == true ]]; then
    partitioning=disko
    green "$host exists and uses disko; its disk layout decides what gets wiped."
  else
    partitioning=premounted
    green "$host exists without disko; it installs onto what is mounted at /mnt."
    require_mnt
    if yes_or_no "Regenerate $host_dir/hardware-configuration.nix from /mnt? Needed if the partitions were recreated."; then
      write_hardware_config "$host_dir/hardware-configuration.nix"
    fi
  fi
  # The flake only sees files git knows about.
  git add "$host_dir"
}

# Sets uses_sops, user, and for sops hosts sops_key_name and host_key_path.
function evaluate_host() {
  green "Evaluating .#$host"
  if ! nix eval --raw "$flake_attr.system.build.toplevel.drvPath" >/dev/null; then
    red "Evaluating .#$host failed; see the nix error above (\"interrupted\" means it was killed, e.g. by earlyoom)."
    exit 1
  fi
  case $(nix eval --json "$flake_attr.hostSpec.disableSops") in
  true) uses_sops=no ;;
  false) uses_sops=yes ;;
  *)
    red "Could not read hostSpec.disableSops for $host."
    exit 1
    ;;
  esac
  if ! user=$(nix eval --raw "$flake_attr.hostSpec.primaryUsername"); then
    red "Could not read hostSpec.primaryUsername for $host."
    exit 1
  fi
  [[ $uses_sops == yes ]] || return 0

  if [[ $HAS_NIX_SECRETS != 1 ]]; then
    red "$host uses sops, but nix-secrets was not found at ${nix_secrets_dir:-<unset>}; set NIX_SECRETS_DIR."
    exit 1
  fi
  require_tools ssh-keygen ssh-to-age yq sops
  local names=() name
  while IFS= read -r name; do
    [[ $name == *"$host"* ]] && names+=("$name")
  done < <(yq '.keys.hosts[] | anchor' "$SOPS_FILE")
  if [[ ${#names[@]} -ne 1 ]]; then
    red "Expected one key under keys.hosts in $SOPS_FILE named like '$host', found: ${names[*]:-none}."
    exit 1
  fi
  sops_key_name=${names[0]}
  # Impermanent hosts read it from the persist volume, before /etc/ssh is mounted.
  if ! host_key_path=$(nix eval --raw "$flake_attr.sops.age.sshKeyPaths" --apply builtins.head); then
    red "Could not read sops.age.sshKeyPaths for $host."
    exit 1
  fi
}

# Built before any prompt, so a failed build never sits between a confirmed wipe and the install.
function build_host() {
  local outputs=("$flake_attr.system.build.toplevel")
  [[ $partitioning != disko ]] || outputs+=("$flake_attr.system.build.diskoScript")
  green "Building $host; the prompts come after this"
  if ! nix build --no-link "${outputs[@]}"; then
    red "Building .#$host failed; see the nix error above. Nothing on $target was touched."
    exit 1
  fi
}

# Confirm the wipe

# Sets disk_id from the host's disko layout and disk_dev from the target; returns 1 when the target lacks that disk.
function resolve_install_disk() {
  local rc=0
  if ! disk_id=$(nix eval --raw "$flake_attr.disko.devices.disk.main.device"); then
    red "Could not read disko.devices.disk.main.device for $host."
    exit 1
  fi
  disk_dev=$(on_target readlink -e "$disk_id") || rc=$?
  [[ $rc -ne 255 ]] || exit 1
  return "$rc"
}

# A disk the host names but the target lacks is replaced in the host's files by one you pick.
function choose_install_disk() {
  local disks missing files=()
  if ! disks=$(nix eval --json "$flake_attr.disko.devices.disk" --apply builtins.attrNames); then
    red "Could not read disko.devices.disk for $host."
    exit 1
  fi
  if [[ $disks != '["main"]' ]]; then
    red "$host's disko layout is not a single disk named main ($disks); install it by hand with nixos-anywhere."
    exit 1
  fi
  if ! resolve_install_disk; then
    yellow "$host's disk $disk_id is not on $target; pick the disk to use instead."
    missing=$disk_id
    pick_disk
    mapfile -t files < <(grep -rlF -- "$missing" "$host_dir")
    if [[ ${#files[@]} -eq 0 ]]; then
      red "Could not find $missing in $host_dir to replace it; set the disk by hand."
      exit 1
    fi
    sed -i "s|$missing|$disk_id|g" "${files[@]}"
    git add "$host_dir"
    green "Set $host's disk to $disk_id in ${files[*]}"
    if ! resolve_install_disk; then
      red "$host's disk $disk_id is still not on $target."
      exit 1
    fi
  fi
  if [[ $disk_dev == "$stick_disk"* ]]; then
    red "$host's disk $disk_id is the installer stick ($stick_disk); refusing to wipe it."
    exit 1
  fi
}

# Asks only when the host's disko layout encrypts a partition, and hands it over at the path that layout reads.
function ask_luks_passphrase() {
  local - password_files password_file passphrase passphrase_again
  set +x
  if ! password_files=$(nix eval --json "$flake_attr.disko.devices.disk.main.content.partitions" \
    --apply 'ps: builtins.filter (f: f != null) (map (p: p.content.passwordFile or null) (builtins.attrValues ps))'); then
    red "Could not read the LUKS password file from $host's disko layout."
    exit 1
  fi
  case $(jq length <<<"$password_files") in
  0) return 0 ;;
  1) password_file=$(jq -r '.[0]' <<<"$password_files") ;;
  *)
    red "$host's disko layout reads more than one LUKS password file ($password_files); install it by hand."
    exit 1
    ;;
  esac
  while true; do
    if ! read -rsp "LUKS passphrase for $host: " passphrase || ! read -rsp $'\nAgain: ' passphrase_again; then
      red "No passphrase entered."
      exit 1
    fi
    echo
    [[ -n $passphrase && $passphrase == "$passphrase_again" ]] && break
    red "Passphrases were empty or did not match."
  done
  passphrase_file=$(mktemp)
  printf '%s' "$passphrase" >"$passphrase_file"
  anywhere_args+=(--disk-encryption-keys "$password_file" "$passphrase_file")
}

function confirm_wipe() {
  local disk_info expected confirm=""
  if ! disk_info=$(on_target lsblk -dno SIZE,MODEL "$disk_dev") || [[ -z $disk_info ]]; then
    red "Could not read the size and model of $disk_id on $target."
    exit 1
  fi
  red "This wipes $disk_dev on $target: $(echo "$disk_info" | xargs), $disk_id"
  expected=${disk_id: -6}
  if ! read -rp "Type the last 6 characters of the disk id ($expected) to wipe it: " confirm || [[ $confirm != "$expected" ]]; then
    red "Got '$confirm', not '$expected'; nothing was changed."
    exit 1
  fi
}

# Rotate the host key

# Kept until an install with it succeeds, so a rerun reuses the key nix-secrets already holds.
function ensure_pending_host_key() {
  pending_key="$pending_dir/ssh_host_ed25519_key"
  if [[ -f $pending_key ]]; then
    green "Reusing the pending host key from an unfinished install of $host"
    [[ -f $pending_key.pub ]] || ssh-keygen -y -f "$pending_key" >"$pending_key.pub"
  else
    install -d -m 700 "$pending_dir"
    rm -f "$pending_key.pub"
    ssh-keygen -q -t ed25519 -N "" -C "root@$host" -f "$pending_key"
  fi
  pending_age_key=$(ssh-to-age <"$pending_key.pub")
}

function registered_key_in() {
  yq ".keys.hosts[] | select(anchor == \"$sops_key_name\")" "$1"
}

# Points the host's key in nix-secrets at the pending key and re-encrypts every secret, unless HEAD already has it.
function register_host_key() {
  local listing files=() file
  if [[ $(git -C "$nix_secrets_dir" show HEAD:.sops.yaml | registered_key_in -) == "$pending_age_key" ]]; then
    return 0
  fi
  # A working copy already on the pending key is an earlier run's re-encrypt cut short; its changes are ours.
  if [[ $(registered_key_in "$SOPS_FILE") != "$pending_age_key" ]]; then
    if [[ -n $(git -C "$nix_secrets_dir" status --porcelain --untracked-files=no) ]]; then
      red "nix-secrets has uncommitted changes; commit or stash them first, since the new host key is committed there."
      exit 1
    fi
    sops_update_age_key hosts "$sops_key_name" "$pending_age_key"
  fi

  green "Re-encrypting nix-secrets for $host's new host key ($sops_key_name = $pending_age_key)"
  if ! listing=$(git -C "$nix_secrets_dir" grep -lE '^sops:|"sops":'); then
    red "Found no sops-encrypted files in $nix_secrets_dir, so nothing was re-encrypted; undo with: git -C $nix_secrets_dir checkout ."
    exit 1
  fi
  mapfile -t files <<<"$listing"
  for file in "${files[@]}"; do
    if ! (cd "$nix_secrets_dir" && sops updatekeys -y "$file"); then
      red "sops updatekeys failed on $file; rerun to retry, or undo with: git -C $nix_secrets_dir checkout ."
      exit 1
    fi
  done
  # Paths given, so anything else already staged in nix-secrets stays out of this commit.
  git -C "$nix_secrets_dir" commit -qm "feat: new host key for $host" -- .sops.yaml "${files[@]}"
}

function push_nix_secrets() {
  local upstream ahead
  if ! upstream=$(git -C "$nix_secrets_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
    red "nix-secrets' branch has no upstream to push the new host key to; set one with: git -C $nix_secrets_dir push -u origin HEAD"
    exit 1
  fi
  ahead=$(git -C "$nix_secrets_dir" rev-list --count "$upstream..HEAD")
  [[ $ahead -gt 0 ]] || return 0
  if ! no_or_yes "Push $ahead nix-secrets commit(s) to $upstream? The install reads the pushed copy."; then
    red "Not pushed and nothing installed; rerun to push and continue."
    exit 1
  fi
  if ! git -C "$nix_secrets_dir" push; then
    red "Pushing nix-secrets to $upstream failed; the commit is kept, so fix that and rerun."
    exit 1
  fi
}

function locked_nix_secrets() {
  jq -r '.nodes[.nodes.root.inputs["nix-secrets"]].locked.rev' flake.lock
}

# Moves flake.lock to the pushed nix-secrets, unless it is already there.
function lock_flake_to_nix_secrets() {
  local head
  head=$(git -C "$nix_secrets_dir" rev-parse HEAD)
  [[ $(locked_nix_secrets) == "$head" ]] || nix flake update nix-secrets
  if [[ $(locked_nix_secrets) != "$head" ]]; then
    red "flake.lock's nix-secrets is at $(locked_nix_secrets), not the pushed $head; the input must follow the branch you pushed."
    exit 1
  fi
  git add flake.lock
}

# After the wipe prompts, so backing out of them leaves nix-secrets untouched.
function rotate_host_key() {
  ensure_pending_host_key
  register_host_key
  push_nix_secrets
  lock_flake_to_nix_secrets
  extra_files=$(mktemp -d)
  install -D -m 600 "$pending_key" "$extra_files$host_key_path"
  install -D -m 644 "$pending_key.pub" "$extra_files$host_key_path.pub"
  anywhere_args+=(--extra-files "$extra_files")
}

# Install

# Plasma suspends an idle stick, so the block is held from connecting through the long build to the reboot.
function keep_stick_awake() {
  local why="just bootstrap is installing" rc=0
  on_target "systemd-inhibit --list --no-pager | grep -q '$why'" >/dev/null || rc=$?
  [[ $rc -ne 0 ]] || return 0
  [[ $rc -ne 255 ]] || exit 1
  # systemd-run returns once the unit starts, before the block is held.
  if ! on_target "systemd-run --collect systemd-inhibit --what=sleep --mode=block --why='$why' /run/current-system/sw/bin/sleep infinity \
    && for _ in 1 2 3 4 5; do systemd-inhibit --list --no-pager | grep -q '$why' && exit 0; sleep 1; done; exit 1" >/dev/null; then
    red "Could not stop $target from sleeping during the install."
    exit 1
  fi
}

function install_host() {
  # From here on a failure leaves the host for a rerun, not for removal.
  new_host_dir=""
  green "Installing $host on $target"
  if ! nix run github:nix-community/nixos-anywhere -- "${anywhere_args[@]}"; then
    red "nixos-anywhere failed.${disk_dev:+ $disk_dev on $target may already be wiped.} $host_dir is kept; rerun to retry."
    exit 1
  fi
  rm -rf "$pending_dir"
  green "$host is installed and rebooting."
  if [[ $uses_sops == no ]]; then
    echo "  - Log in as $user with password 'changeme' and run passwd."
  fi
  echo "  - $host_dir is staged; commit it."
}

positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  --port)
    ssh_port=$2
    shift
    ;;
  -k)
    ssh_key=$2
    shift
    ;;
  --debug) set -x ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*) usage_error "Unknown option: $1" ;;
  *) positional+=("$1") ;;
  esac
  shift
done

[[ ${#positional[@]} -eq 2 ]] || usage_error "Expected <hostname> <ip>, got ${#positional[@]} arguments."
host=${positional[0]}
target=${positional[1]}
if [[ ! $host =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  red "Hostname '$host' must be lowercase letters, digits and dashes."
  exit 1
fi
require_tools ssh git nix jq

cd "$(git rev-parse --show-toplevel)"
host_dir="hosts/nixos/$host"
flake_attr=".#nixosConfigurations.$host.config"
pending_dir="${XDG_STATE_HOME:-$HOME/.local/state}/bootstrap/$host"
anywhere_args=(--flake ".#$host" --target-host "root@$target" --ssh-port "$ssh_port")
[[ -n $ssh_key ]] && anywhere_args+=(-i "$ssh_key")

passphrase_file=""
extra_files=""
staging=""
# Set while a host this run created could be left half-made; cleared once the install starts.
new_host_dir=""
function cleanup() {
  rm -rf "$passphrase_file" "$extra_files" "$staging"
  if [[ -n $new_host_dir ]]; then
    yellow "Removing the unfinished $new_host_dir"
    git rm -rq --cached --ignore-unmatch "$new_host_dir"
    rm -rf "$new_host_dir"
  fi
}
trap cleanup EXIT

connect_to_stick
keep_stick_awake
prepare_host
evaluate_host
build_host
if [[ $partitioning == disko ]]; then
  choose_install_disk
  ask_luks_passphrase
  confirm_wipe
  # The stick is already a NixOS installer, so there is nothing to kexec into.
  anywhere_args+=(--phases "disko,install,reboot")
else
  anywhere_args+=(--phases "install,reboot")
fi
[[ $uses_sops == no ]] || rotate_host_key
install_host
