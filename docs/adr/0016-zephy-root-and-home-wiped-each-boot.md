---
status: accepted
date: 2026-10-31
---

# zephy's root and home are wiped each boot, from an encrypted btrfs disk

## Context and Problem Statement

zephy is a laptop on a hand-partitioned ext4 root, so state piles up unseen and
nothing says which of it matters. It moves to disko and impermanence: every boot
starts from an empty root, and only listed paths survive. Sign-ins (1Password,
browsers, Spotify, Steam, chat) and the secrets keys must survive.

## Considered Options

Disk:

1. LUKS around one btrfs partition with `@root`, `@nix`, `@persist` subvolumes.
2. Plain btrfs, unencrypted.

Wipe:

1. An initrd service moves `@root` to `old_roots/<timestamp>`, keeps 30 days,
   and creates an empty `@root`.
2. `/` on tmpfs.

Home:

1. Home wiped with root; each kept path listed under
   `environment.persistence."/persist".users.<user>`.
2. `/home` as its own persistent subvolume.

## Decision Outcome

Chosen: LUKS, rollback, home wiped.

- Plain btrfs rejected: a lost laptop exposes the sops host key, the user age
  key and every signed-in session.
- tmpfs rejected: a path missing from the persist list is gone at reboot with no
  copy, and nix builds in `/tmp` would fill RAM.
- Persistent `/home` rejected: home is where most of the unseen state lives,
  which the wipe is meant to surface.

### Consequences

- Good: anything forgotten is in `/old_roots` for 30 days, mounted from the
  top-level subvolume.
- Neutral: sshd and sops read the host key in place under `/persist/etc/ssh`.
  Activation runs in initrd and writes `/etc/ssh`, so persisting `/etc/ssh`
  would cover `sshd_config` and `authorized_keys.d` with stale copies.
- Bad: `/etc/shadow` is rebuilt each boot, so `passwd` changes revert; addg's
  password comes from sops, gamer's stays `changeme`.
- Bad: the home persist list needs updating whenever an app is added whose state
  should survive.
- Bad: a passphrase at every boot.
- Bad: reinstalling wipes the disk; the host key and the user age key must be
  restored into `/persist` or sops cannot decrypt.
