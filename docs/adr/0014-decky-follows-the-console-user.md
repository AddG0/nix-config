---
status: accepted
date: 2026-10-30
---

# Decky follows the console user, with per-user plugin data

## Context and Problem Statement

Decky Loader runs as root and drops each plugin to one fixed unprivileged user,
set once (Jovian's `jovian.decky-loader.user`, upstream at install time). rig-pc
has two console users: in `addg`'s session Decky's plugins still ran as `gamer`,
so Deckify's Spotify Connect and Deckcord's voice reached the wrong session, and
both users shared one Spotify and one Discord login. Upstream supports a single
user; no prior art for several was found. Details:
`docs/work/decky-per-user/design.md`.

## Considered Options

1. A root `pam_exec` hook on the console display managers' session stack writes
   the logged-in user into an `EnvironmentFile=` overriding Jovian's
   `UNPRIVILEGED_USER`/`UNPRIVILEGED_PATH`, and restarts `decky-loader`. Plugin
   data lives in each user's `~/.local/share/decky`; `PRIVILEGED_PATH` keeps the
   plugins and `loader.json` shared in `/var/lib/decky-loader`.
2. Same, but one shared data dir re-owned at each switch.
3. One Decky per user as a user service.
4. A user-level unit that asks polkit to restart Decky.

## Decision Outcome

Chosen: option 1.

- Option 2 rejected: users share one Spotify and one Discord login.
- Option 3 rejected: Decky must run as root to drop privileges per plugin, and
  running it unprivileged is unsupported upstream.
- Option 4 rejected: user managers start for SSH logins too, so an SSH session
  would take Decky from the console user.

### Consequences

- Good: each console user gets Decky plugins running as them, with their own
  logins and settings; the declared plugin set and loader settings stay shared.
- Good: works under SDDM and greetd; hosts without Decky are unaffected.
- Bad: every console login that changes the user restarts Decky (a few seconds
  without its menu); a first login per user starts plugins unconfigured.
- Bad: plugins writing outside `DECKY_HOME` (hardcoded `/home/deck`) still share
  or fail as before.
- Neutral: before any console login, Decky runs for Jovian's configured user,
  with that user's data, so the autologin user's login restarts nothing.
- Neutral: the data in the old shared dir moves once into that user's home.
