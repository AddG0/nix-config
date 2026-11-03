# Secure Boot and TPM unlock

LUKS host boots without the passphrase: lanzaboote signs the boot chain with our
keys, the TPM releases the disk key only to that Secure Boot state (PCR 7). The
passphrase stays as fallback.

For the encrypted disko layouts (`luks-btrfs.nix`, `luks-btrfs-impermanence.nix`):
LUKS device `crypted` on `/dev/disk/by-partlabel/disk-main-luks`.

## Steps

| # | Where | Do | Expect |
|---|-------|----|--------|
| 0 | host | `systemd-cryptenroll --tpm2-device=list` | a TPM 2.0 |
| 1 | config | import `secureboot`; set `boot.initrd.luks.devices.crypted.crypttabExtraOpts = ["tpm2-device=auto"]`; impermanent: persist `/var/lib/sbctl` | — |
| 2 | host | `sudo nix run nixpkgs#sbctl -- create-keys` | keys in `/var/lib/sbctl` |
| 2b | host, impermanent | `sudo mkdir -p /persist/var/lib && sudo cp -a /var/lib/sbctl /persist/var/lib/` | — |
| 3 | host | `just rebuild` (after `boot`, reboot before step 4) | "Successfully installed Lanzaboote" |
| 4 | host | `sudo sbctl verify`; `sudo ls /boot/loader/keys/auto` | all ✓ but `/EFI/nixos/kernel-*.efi`; `PK.auth KEK.auth db.auth` |
| 5 | firmware | `systemctl reboot --firmware-setup` → Key Management → **Clear Secure Boot Keys** | 15 s "Enrolling in…" countdown, any key aborts; then "successfully enrolled, rebooting" |
| 6 | host | `bootctl status` | `disabled`, not `(setup)`; still `(setup)`: `sudo sbctl enroll-keys --microsoft` |
| 7 | firmware | Secure Boot → **Enabled** | `bootctl status`: `enabled (user)` |
| 8 | host | `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-main-luks` | next boot: no prompt |

Order matters: keys before rebuild (else `db.pem` not found), clear before
enroll, Secure Boot on before the TPM (turning it on changes PCR 7). The
`secureboot` module stages the keys on `/boot` at step 3; systemd-boot enrolls
them only while the firmware is in Setup Mode. After new keys, `sudo rm -r
/boot/loader/keys/auto` and switch, or Setup Mode enrolls the old ones.

## Firmware without Setup Mode (freya)

Razer hides key management, so our key goes in shim's MOK list instead of the
firmware db. Import `secureboot` and `secureboot-shim`; the chain is factory keys
→ Ubuntu's Microsoft-signed shim → lanzaboote's systemd-boot as
`\EFI\shim\grubx64.efi`. Steps 1–4 as above, then:

| # | Where | Do | Expect |
|---|-------|----|--------|
| 5 | host | `efibootmgr` | `NixOS (shim)` first in `BootOrder` |
| 6 | host | `sudo openssl x509 -in /var/lib/sbctl/keys/db/db.pem -outform DER -out /tmp/db.der && sudo mokutil --import /tmp/db.der` | asks for a one-time password |
| 7 | firmware | reboot → blue MokManager → **Enroll MOK** → Continue → password | reboots |
| 8 | host | `mokutil --list-enrolled` | our db cert listed |
| 9 | firmware | Secure Boot → **Enabled**, Microsoft UEFI CA left on | `bootctl status`: `enabled (user)` |

Then step 8 of the table above for the TPM. If the firmware drops the
`NixOS (shim)` entry (BIOS update, CMOS reset), turn Secure Boot off, boot, and
`secureboot-shim.service` recreates it.

## Don't

- **Delete anything in `/boot/EFI`.** The ✗ on `/EFI/nixos/kernel-*.efi` is
  expected: lanzaboote's signed stub loads it by hash. Without `/EFI/nixos` every
  generation fails with "Failed to read kernel file into memory".
- **Enable Secure Boot before step 6.** "Invalid signature detected"; disable it
  in the firmware to boot.

## TPM stopped unlocking

Firmware update, new keys or Secure Boot off changes PCR 7. Type the passphrase,
then:

```sh
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-main-luks
```

## Reinstall the bootloader from the installer stick

Secure Boot not enforcing. Root ssh to the stick works, so everything after
`cryptsetup open` can run from demon.

```sh
sudo cryptsetup open /dev/disk/by-partlabel/disk-main-luks crypted
sudo mount -o subvol=@root /dev/mapper/crypted /mnt
sudo mount -o subvol=@nix /dev/mapper/crypted /mnt/nix
sudo mount /dev/disk/by-partlabel/disk-main-ESP /mnt/boot
# impermanent hosts:
sudo mount -o subvol=@persist /dev/mapper/crypted /mnt/persist
sudo mkdir -p /mnt/var/lib/sbctl && sudo mount --bind /mnt/persist/var/lib/sbctl /mnt/var/lib/sbctl

sudo nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
sudo umount -R /mnt && sudo cryptsetup close crypted
```

## Gotcha

`sudo ls /boot/…/*.conf` → "no matches": zsh globs as you. Use
`sudo sh -c 'ls /boot/…/*.conf'`.
