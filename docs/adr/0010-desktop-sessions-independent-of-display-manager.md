---
status: accepted
date: 2026-10-29
---

# Desktop sessions are our own session entries, so Gaming Mode works under any display manager

## Context and Problem Statement

Gaming Mode's desktop ↔ gamescope switching runs every desktop through
`session-dispatcher`, which loops between the two halves inside one login.
It reached the dispatcher only through `services.greetd.sessionCommand`, the
raw command greetd's `initial_session` and tuigreet's `--cmd` run, and the
whole module sat behind `mkIf config.services.greetd.enable`.

Display managers other than tuigreet launch a session's `.desktop` entry, not
a command:

- noctalia-greeter (demon) runs the entries in `sessionData.desktops`, so a
  login there started the plain `hyprland-uwsm` entry and skipped the
  dispatcher. "Gaming Mode" from the launcher then ended the session.
- azuree runs SDDM, so the module was off and Gaming Mode did not exist.

Moving to SDDM (SilentSDDM) needs the switching to work without greetd.

## Considered Options

1. Our own entries, under the upstream file names, placed first in
   `services.displayManager.sessionPackages`, so they replace upstream's.
   Gaming Mode sets a wrapper every desktop entry runs through.
2. Wrapped entries under new names beside upstream's, picked by
   `defaultSession`.
3. `mkForce` the whole `sessionPackages` list to ours.
4. Keep greetd's command path and write a matching adapter per display
   manager (SDDM's autologin config, as SteamOS does).
5. Run gamescope from a systemd user service, outside the login session.

## Decision Outcome

Chosen: option 1.

`desktops.sessions.<desktop>` (in `modules/hosts/nixos/desktop-sessions`)
holds each session's display name, `DesktopNames` and command, set by the
desktop modules; its `sessionName` is the upstream entry it replaces.
Gaming Mode sets `desktops.sessionWrapper`, registers `gaming-mode`, and
sets `services.displayManager.autoLogin` for the standalone shape.
`defaultSession` follows `desktops.primarySession`. greetd is now an
adapter: it ignores `defaultSession` and `autoLogin`, so it runs
`start-session <name>`, which execs that entry's `Exec=`.

- Option 2 rejected: every desktop shows twice in the greeter, and picking
  the upstream one silently loses Gaming Mode. SDDM and noctalia-greeter
  remember the last pick, so a single wrong pick sticks.
- Option 3 rejected: it also drops sessions from modules that are not ours,
  and the next desktop module would have to know about it.
- Option 4 rejected: one adapter per display manager to keep correct, and
  greeters that launch entries (noctalia-greeter) still bypass the
  dispatcher.
- Option 5 rejected: gamescope needs DRM master, which the compositor holds
  for as long as the login session runs. A second session needs a VT switch
  and a second login.

### Consequences

- Good: switching works under greetd, SDDM and any display manager that
  reads `sessionData`, including on azuree. It returns to the desktop the
  session started, not always Hyprland.
- Good: the greeter lists each desktop once, and the session names stay the
  same, so `defaultSession` and remembered picks are unaffected.
- Bad: it relies on nixpkgs' session list keeping the first entry of a name
  (`lndir` in `display-managers/default.nix` warns and keeps the existing
  link). If nixpkgs reverses that order, upstream's entries win and the
  dispatcher is skipped without an error.
- Bad: each desktop's `Exec=` is a copy of upstream's, which we keep in step
  by hand after a bump.
- Neutral: Hyprland's plain `hyprland.desktop`, which `uwsm start` launches,
  is replaced by a copy marked `NoDisplay=true`, so greeters list only the
  uwsm entry. SDDM and noctalia-greeter skip `NoDisplay`; uwsm refuses only
  `Hidden`.
- Good: "Gaming Mode" from the launcher works in every registered desktop.
  Each session carries a `stop` command, which the launcher looks up through
  `XDG_CURRENT_DESKTOP`. The launcher refuses with a notification when the
  dispatcher's lock is free, which means a session picked outside our entries.
- Bad: each `stop` is the desktop's own logout command (`uwsm stop`,
  `niri msg action quit`, Plasma's `org.kde.Shutdown.logout`), kept by hand.
