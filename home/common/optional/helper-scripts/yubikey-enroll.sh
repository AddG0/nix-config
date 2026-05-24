#!/usr/bin/env bash
# Enroll yubikey(s) for PAM U2F so sudo/login prompt "Please touch the device"
# instead of asking for a password.
#
# Per-host, per-user: writes ~/.config/Yubico/u2f_keys, which pam_u2f reads
# at auth time. The file is not synced between hosts — run this on each
# machine where you want the touch prompt (any host with
# `yubikey.enable = true` from modules/hosts/nixos/yubikey.nix).
#
# Safe to re-run later. If u2f_keys already exists, the script offers to
# [a]ppend (enroll an additional key without re-tapping existing ones) or
# [o]verwrite (start fresh, e.g. after losing a key).
#
# Without enrollment, pam_u2f falls through to password — sudo still works,
# just with no touch prompt.

set -euo pipefail

AUTH_FILE="$HOME/.config/Yubico/u2f_keys"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

bold "Yubikey PAM U2F enrollment for $USER@$(hostname)"
echo

if [[ -f $AUTH_FILE ]]; then
	existing_keys=$(awk -F: '{print NF - 1}' "$AUTH_FILE" 2>/dev/null || echo 0)
	yellow "Existing enrollment found at $AUTH_FILE ($existing_keys key(s) enrolled)"
fi

mkdir -p "$(dirname "$AUTH_FILE")"

mode="new"
if [[ -f $AUTH_FILE ]]; then
	echo
	read -rp "[a]ppend a new key, [o]verwrite everything, [c]ancel? [a/o/c] " choice
	case "${choice,,}" in
	a) mode="append" ;;
	o) mode="new" ;;
	*)
		echo "Aborted."
		exit 0
		;;
	esac
fi

count=0
if [[ $mode == "append" ]]; then
	count=$(awk -F: '{print NF - 1}' "$AUTH_FILE" 2>/dev/null || echo 0)
fi

echo "Plug in a yubikey and tap when it flashes."
read -rp "Press enter when ready..."

if [[ $mode == "new" ]]; then
	TMP="$(mktemp)"
	trap 'rm -f "$TMP"' EXIT
	if ! pamu2fcfg >"$TMP"; then
		red "pamu2fcfg failed. Aborting."
		exit 1
	fi
	mv "$TMP" "$AUTH_FILE"
else
	if ! pamu2fcfg -n >>"$AUTH_FILE"; then
		red "pamu2fcfg failed. Previously enrolled keys are still saved."
		exit 1
	fi
fi
count=$((count + 1))
green "✓ Key $count enrolled."

while true; do
	echo
	read -rp "Enroll another key? [y/N] " ans
	[[ ${ans,,} == "y" ]] || break

	echo "Unplug current key, plug in the next one. Tap when it flashes."
	read -rp "Press enter when ready..."

	if ! pamu2fcfg -n >>"$AUTH_FILE"; then
		red "pamu2fcfg failed for this key. Previously enrolled keys are still saved."
		exit 1
	fi
	count=$((count + 1))
	green "✓ Key $count enrolled."
done

echo
green "Done. $count key(s) enrolled to $AUTH_FILE"
echo
echo "Test it:"
echo "  sudo -k && sudo true"
echo "Should prompt 'Please touch the device' instead of asking for password."
