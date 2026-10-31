---
status: accepted
date: 2026-10-31
---

# Game-folder files in a shared Steam library have one writer, on the host

## Context and Problem Statement

rig-pc's users share `/srv/steam-library`. steam-config-nix places declared
files into game folders (Automobilista 2's ReShade setup) once per user, each
keeping its own record set. A second user then backs up the first user's file as
the game's own, and removing the setting from the config can restore it,
leaving it unmanaged. Placement also depends on that user's Steam having run on
the host and on their session being up at rebuild. The files must arrive with
either user, both or nobody signed in, with or without autologin, and leave
cleanly when removed from the config. Details:
`docs/work/shared-steam-library/design.md`.

## Considered Options

1. A system service owns the shared library's game-folder files: it applies the
   union of every user's declared `files.game.place` with steam-config-patcher's
   own `apply_file_ops`, one record set in `/var/lib/steam-library-files`, at
   each config change, at boot, and on writes to `steamapps/`.
2. Every user writes.
3. Only the primary user writes.
4. Only the desktop (autologin) user writes.
5. All users share one steam-config-nix state directory.
6. vkBasalt, with nothing written into game folders.

## Decision Outcome

Chosen: option 1.

- Option 2 rejected: removal can leave unmanaged files, depending on which
  user's activation runs last.
- Option 3 rejected: nothing is placed while that user has never run Steam on
  the host.
- Option 4 rejected: still needs a session at rebuild; the autologin user does
  not linger.
- Option 5 rejected: the record set also holds per-user prefix entries, which
  would collide, and concurrent activations race.
- Option 6 rejected: no in-game overlay, presets converted by hand, no depth or
  multi-pass shaders.

### Consequences

- Good: placement needs no user session; a game installed after a rebuild gets
  its files from the path trigger; removal reverts through the one record set.
- Good: hosts without a shared library are unchanged.
- Bad: the service imports steam-config-patcher internals (`apply_file_ops`,
  `FileOp`); an upstream refactor breaks it, caught by the build-time check.
- Bad: on a shared-library host, games installed in a user's own library get no
  game-folder files.
- Neutral: `files.game.patch` and `.remove`, and install-record settings, stay
  per user until a game needs them in the shared library.
