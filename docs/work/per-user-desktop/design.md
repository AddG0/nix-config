# Per-user desktop: each user's home picks the desktop they land in

## Goal

On a host with several desktops installed, each user gets their own desktop by
default, wherever a session starts without an explicit pick:

- autologin,
- Gaming Mode's "Switch to Desktop",
- the greeter's default entry.

The choice is a home-manager option, so it lives with the rest of that user's
config and works the same on every host and every display manager.

Driving case: rig-pc runs Gaming Mode as `gamer`, who should land in Plasma,
while `addg` could use Hyprland on the same host.

## Non-goals

- Hiding sessions from users. SDDM and tuigreet list every installed session to
  everyone; the explicit entries (Plasma, Hyprland…) stay for one-off picks.
- Per-user desktop *home* config. Suites keep handing their home halves to every
  host user (tried and reverted 2026-10-30: the config being present but unused
  costs nothing, and it bought little while the session choice stayed host-wide).
- Changing standalone Gaming Mode hosts, which have no desktop to switch to.
- Choosing a desktop per user on hosts that install only one.

## Current state

From `modules/hosts/nixos/desktop-sessions` and `gaming/gamescope-session`:

| Path | Decided by |
|---|---|
| Sessions offered | every `desktops.sessions` entry the host's desktop modules register |
| Autologin | `desktops.loginSession` (defaults to `primarySession`) |
| Greeter default | `services.displayManager.defaultSession`, from `loginSession`; SDDM may also remember a last session (unverified: `/var/lib/sddm/state.conf` is root-only) |
| Switch to Desktop | `desktops.primarySession`, baked into the Gaming Mode entry: `session-dispatcher gamescope <primary desktop command>` |
| Desktop → Gaming Mode | `enter-gaming-mode`, which stops whatever desktop runs via `XDG_CURRENT_DESKTOP`; per-user already |

Every row but the last is host-wide.

## Design

### The home option

A home-manager option next to `desktops.catppuccin` in `modules/common/desktops.nix`
(loaded on NixOS, darwin and home-manager):

```nix
desktops.defaultSession = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  example = "plasma";
  description = "Key of desktops.sessions this user lands in when nothing else picks one.";
};
```

Keys are the host's `desktops.sessions` keys (`plasma`, `hyprland-uwsm`, `niri`…),
so one name space covers both sides. On a Linux home it writes
`$XDG_CONFIG_HOME/desktops/default-session` holding the key; null writes nothing.
On darwin it is inert: declared by the shared module so a shared home setting
evaluates everywhere, but nothing writes or reads it.

Each desktop's shared home module sets it with `lib.mkDefault`, so importing
Plasma's home module alone makes Plasma the user's default. A home with several
desktops (demon's addg: Hyprland, niri, Plasma) sets it explicitly; two
`mkDefault`s of different values are an evaluation error, which is the prompt to
choose.

### The launcher session

A new session in `desktop-sessions`, registered only when the host has more than
one desktop:

```
desktops.sessions.desktop = {
  displayName = "Desktop";            # greeter label
  command = "<desktop-launcher>";
  desktop = false;                    # not itself wrapped or a fallback
};
```

It is visible in the greeter: a hidden entry could only be reached as the
default, so a user who once picked an explicit desktop would have no way back to
their own from the login screen.

`desktop-launcher` reads `~/.config/desktops/default-session`. If the key names
a registered desktop session it `exec`s `start-session <key>`; otherwise it logs
why and falls back to `primarySession`. It runs the chosen desktop exactly as
picking it in the greeter would, `sessionWrapper` included.

### Wiring the three paths

1. **Greeter default and autologin:** `loginSession` defaults to `desktop` when
   the launcher exists, so SDDM's and greetd's default/autologin pick the user's
   desktop. A host overriding `loginSession` (rig-pc: `gaming-mode`) keeps it.
2. **Switch to Desktop:** the Gaming Mode entry becomes
   `session-dispatcher gamescope <desktop-launcher>`, so the desktop half is the
   logged-in user's preference rather than `primarySession`.
3. **Desktop → Gaming Mode:** unchanged.

### Checks

- NixOS assertion per home-manager user: a non-null `desktops.defaultSession`
  must be a key of the host's `desktops.sessions`, naming the user and the host's
  keys in the message.
- Unit tests (`modules/hosts/nixos/desktop-sessions/tests`, the existing harness):
  the launcher picks the file's session, falls back on a missing file, an empty
  file and an unknown key, and logs each fallback.

### Verification

Before/after snapshot of every host's evaluated sessions, `loginSession`,
`defaultSession` and Gaming Mode command; every home's packages and files. Hosts
with one desktop must come out identical.

## Alternatives considered

1. **Per-user map in `hostSpec`** (`hostSpec.desktops.gamer = "plasma"`).
   Rejected: the preference is the user's, and a home-manager option keeps it in
   their home file; also needs no runtime file. It would let the dispatcher bake
   the command at build time instead of reading a file.
2. **AccountsService per-user `Session=`.** Rejected: it is mutable state set
   outside Nix, and greeters differ in whether they honour it (not checked per
   greeter).
3. **Per-user `loginSession` / autologin target only.** Rejected: leaves Switch to
   Desktop host-wide, which is the path gamer actually uses.
4. **Read the preference from the user's home-manager generation instead of a
   file.** Rejected for now: ties the launcher to home-manager's profile layout;
   a plain file also works for a user who sets it by hand.

## Decisions (2026-10-30)

1. Named `desktops.defaultSession`: clearer than `preferredSession`, and it reads
   as the user's counterpart of `services.displayManager.defaultSession`.
2. The "Desktop" entry is visible (see above).
3. darwin homes get the option inert rather than an error, so shared home config
   stays reusable across platforms.

## Risks

- A typo'd or stale preference only shows at login. Mitigated by the assertion at
  build time and the logged fallback at runtime.
- If SDDM remembers a last session, it may override the default after a user
  picks an explicit entry once. Unverified; settle with `sudo cat
  /var/lib/sddm/state.conf` on rig-pc before relying on the greeter default.
- The Gaming Mode command no longer names a desktop at build time, so a broken
  launcher breaks Switch to Desktop; the fallback to `primarySession` is the guard.

## Addendum: implementation (2026-10-30)

Supersedes the design above where they differ.

- The launcher is not a `desktops.sessions` key. Whether it exists depends on how
  many desktops `desktops.sessions` holds, so registering it there recurses;
  `desktop-sessions` renders its "Desktop" entry beside the others instead, and
  `loginSession = "desktop"` maps to it.
- Gaming Mode reads the new read-only `desktops.defaultDesktopCommand` (the
  launcher with several desktops, else the primary desktop's command), so a
  single-desktop host's Gaming Mode command is unchanged.
- The option lives in `modules/home/desktops.nix`, home-manager only: a NixOS
  `desktops.defaultSession` would sit confusingly beside `loginSession`.
- The launcher reads the file with `head`, so an empty file falls back like a
  missing one instead of tripping `errexit`.
- Verified: of all hosts, only demon (three desktops) changed its sessions; every
  desktop home gained only `.config/desktops/default-session`; the ten hosts
  without a desktop kept byte-identical homes.
