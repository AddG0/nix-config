---
status: accepted
date: 2026-10-29
---

# A login screen is one import that brings its own login manager

## Context and Problem Statement

A host picked its login screen with two imports: `greetd`, which also carried
tuigreet as a fallback greeter, and a greeter such as `noctalia-greeter` on
top. Adding `silent-sddm` meant a switch removed both greetd imports and added
the SDDM one. Nothing caught a greeter imported without greetd, and tuigreet
could not be picked explicitly.

nixpkgs models it in layers: shared session data under
`services.displayManager`, one enable per login manager, and greetd greeters
(`programs.regreet`, `services.displayManager.noctalia-greeter`) that turn
greetd on themselves.

## Considered Options

1. One import per login screen, as nixpkgs does, grouped like its
   `services/display-managers/`: `display-managers.{tuigreet,noctalia-greeter,silent-sddm}`,
   the greetd ones importing a private `_greetd.nix` adapter.
2. One module on every host with an option naming the login screen.
3. Keep the separate `greetd` import, with an assertion against greetd and
   SDDM together.

## Decision Outcome

Chosen: option 1.

- Option 2 rejected: the module tree's convention is that importing a module
  is the choice (ADR 0001), and every greeter's flake module would be
  imported, so evaluated, on every host.
- Option 3 rejected: a switch edits two lines that must change together, and a
  greeter without greetd goes unnoticed.

### Consequences

- Good: switching a host's login screen is one import swapped.
- Good: `_greetd.nix` holds only what greetd needs from us: `start-session`
  for `defaultSession` and `autoLogin`, and the greeter's user.
- Bad: nothing but `silent-sddm`'s assertion stops two login screens being
  imported; nixpkgs has no such check either, and two greetd greeters conflict
  on `default_session.command` instead.
- Neutral: PAM settings per login manager (keyring, YubiKey, fingerprint)
  stay in the modules that own them, gated on that login manager being
  enabled. Fingerprint login is still greetd-only.
