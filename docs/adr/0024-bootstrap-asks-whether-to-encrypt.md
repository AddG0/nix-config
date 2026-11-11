---
status: accepted
date: 2026-11-11
---

# Bootstrap asks whether to encrypt a wiped disk

Supersedes in part [ADR 0017](0017-hosts-installed-from-demon-over-ssh.md):
LUKS + btrfs stays the default for new disko hosts, but is no longer the only
layout.

## Context and Problem Statement

`just bootstrap` gave a new host two choices: wipe a disk with LUKS + btrfs, or
install onto `/mnt`. Unattended machines such as home-assistant boxes have no
one at the console to type a passphrase at boot, so LUKS stops them coming back
after a power cut.

## Considered Options

1. One three-way menu: LUKS btrfs, plain btrfs, or `/mnt`.
2. Keep the partitioning question, then ask "Encrypt it with LUKS? [Y/n]" only
   after a disk is chosen for wiping.
3. Merge `luks-btrfs.nix` and `btrfs.nix` into one disko module with an
   `encrypt` option, as EmergentMind's `system.disks.luks.enable` does.

## Decision Outcome

Chosen: option 2, with a new `hosts/common/disks/btrfs.nix` that matches
`luks-btrfs.nix` without the LUKS layer.

- Option 1 rejected: it mixes two separate decisions in one list, and each
  later axis (swap, TPM unlock) would multiply the letters. Calamares,
  archinstall and the Ubuntu installer all ask about encryption separately from
  partitioning.
- Option 3 rejected for now: it rewrites the layout existing hosts import, for a
  choice made once at install time. Switching later is a reinstall either way.

### Consequences

- Good: Enter keeps the encrypted default; `n` gives a host that boots unattended.
- Neutral: the scaffold's `disko.nix` names its layout through `@LAYOUT@`, and
  `checks/configurations.nix` evaluates the template once per layout.
