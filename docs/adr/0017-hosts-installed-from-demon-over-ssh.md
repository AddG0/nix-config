---
status: accepted
date: 2026-10-31
---

# Hosts are installed from demon over SSH, onto a machine booted from our installer stick

## Context and Problem Statement

A new machine needs a host in this flake before NixOS can be installed from it:
a disk, hardware config and hostname that only exist once the machine is booted.
The old `just disko` recipe pointed at a deleted file, and
`scripts/bootstrap-nixos.sh` cd'd into a deleted directory.

## Considered Options

Installer:

1. Our ISO (`hosts/nixos/installer`) runs sshd; `just bootstrap` on demon drives
   nixos-anywhere against it.
2. An `install-system` script on the stick, run on the target itself.
3. Calamares on the stick.

Hardware config:

1. nixos-facter for disko hosts, nixos-generate-config for hosts mounted by hand.
2. nixos-generate-config for both.

Disk layout for new disko hosts:

1. A new `luks-btrfs.nix`: LUKS, `@root`/`@home`/`@nix`, kept across boots.
2. `luks-btrfs-impermanence.nix`, as zephy uses.

## Decision Outcome

Chosen: installs from demon, facter for disko hosts, plain LUKS + btrfs.

- On-stick script rejected: the new host would be written on the stick and
  pushed back, instead of in demon's checkout where it is committed.
- Calamares rejected: it writes a channel `configuration.nix` and its own
  partition layout, so every machine would be installed twice.
- nixos-generate-config for disko hosts rejected: disko already owns their
  `fileSystems`, and facter's report needs no hand edits.
- Impermanent layout rejected as the default: each new host would need a
  persist list before its sign-ins survive a reboot.

### Consequences

- Good: the disk id only matters while formatting; disko mounts by partition
  label, so the id in `disko.nix` can be fixed later without reinstalling.
- Neutral: hosts without disko (dual boot, existing partitions) are partitioned
  by hand on the stick and installed with `--phases install,reboot`.
- Neutral: a sops host gets a new host key on every install; its age key in
  nix-secrets is replaced and the secrets re-encrypted before installing. Old
  keys are never copied off a machine. The new key stays on demon until an
  install with it succeeds, so a rerun does not rotate again.
- Bad: new hosts start with `disableSops = true`; adding one to nix-secrets is
  still manual.
- Bad: installing needs demon and the stick on the same network.
