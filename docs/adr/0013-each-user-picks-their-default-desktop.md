---
status: accepted
date: 2026-10-30
---

# Each user picks the desktop they land in

## Context and Problem Statement

Hosts can install several desktops, and a host can have several users, but the
desktop a session lands in when nobody picks one was host-wide: autologin and the
greeter default followed `desktops.loginSession`, and Gaming Mode's Switch to
Desktop ran `desktops.primarySession`'s command, baked in at build time. On
rig-pc, `gamer` and `addg` could not land in different desktops. Details and
alternatives: `docs/work/per-user-desktop/design.md`.

## Considered Options

1. A home-manager option, `desktops.defaultSession`, read at login by a
   "Desktop" launcher session that every unpicked path starts.
2. A per-user map in `hostSpec`, baked into each path at build time.
3. AccountsService's per-user `Session=`.
4. Per-user autologin target only.

## Decision Outcome

Chosen: option 1. The home option writes `~/.config/desktops/default-session`;
hosts with more than one desktop get a "Desktop" greeter entry, `loginSession`
defaulting to it, and Gaming Mode's desktop half running it. A desktop's home
module sets the option with `mkDefault`, so a single-desktop home needs nothing;
a home with several must choose.

- Option 2 rejected: the choice belongs to the user's home, not the host file.
- Option 3 rejected: mutable state outside Nix, honoured unevenly by greeters.
- Option 4 rejected: Switch to Desktop, the path a Gaming Mode user takes, stays
  host-wide.

### Consequences

- Good: the same mechanism works under any display manager and on every host.
- Good: a build fails when a user's default names a desktop the host lacks; at
  runtime a missing, empty or unknown default falls back to `primarySession`
  and says why.
- Bad: Gaming Mode's command no longer names a desktop at build time, so the
  launcher is on the Switch to Desktop path; its fallback is the guard.
- Neutral: single-desktop hosts get no launcher and behave as before.
