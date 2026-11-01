#!/usr/bin/env bash
# Writes result/iso/*.iso to a USB drive, asking which one when none is given.
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

drive=${1:-}
isos=(result/iso/*.iso)
if [[ ! -f ${isos[0]} ]]; then
  red "No ISO in result/iso/; build one first."
  exit 1
fi

if [[ -z $drive ]]; then
  drives=()
  mapfile -t drives < <(lsblk -dpno NAME,SIZE,MODEL,TRAN | awk '$NF == "usb"')
  if [[ ${#drives[@]} -eq 0 ]]; then
    red "No USB drives found; plug the stick in or pass the drive."
    exit 1
  fi
  blue "USB drives:"
  choice=""
  select choice in "${drives[@]}"; do
    [[ -n $choice ]] && break
  done
  if [[ -z $choice ]]; then
    red "No drive chosen."
    exit 1
  fi
  drive=${choice%% *}
fi

if [[ ! -b $drive ]]; then
  red "$drive is not a block device."
  exit 1
fi
# Checked for a drive passed by hand too, so an internal disk is never a target.
if [[ $(lsblk -dno TRAN "$drive") != usb ]]; then
  red "$drive is not a USB drive ($(lsblk -dno TRAN,MODEL "$drive" | xargs)); refusing to overwrite it."
  exit 1
fi
if lsblk -no MOUNTPOINTS "$drive" | grep -q .; then
  red "$drive has mounted partitions; unmount them first:"
  lsblk -o NAME,SIZE,MOUNTPOINTS "$drive" >&2
  exit 1
fi

lsblk -o NAME,SIZE,MODEL,TRAN "$drive"
if ! no_or_yes "Overwrite everything on $drive with ${isos[0]}?"; then
  red "Nothing was written."
  exit 1
fi
sudo dd if="${isos[0]}" of="$drive" bs=4M status=progress oflag=sync
