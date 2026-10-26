# Desktop layers: shared apps, a bare-compositor kit, thin compositors

## Goal

One line enables a desktop on a host, several desktops coexist on one host
(demon: Hyprland + niri, sometimes Plasma), and each piece of desktop config
lives exactly once:

- `useSuite suites.<desktop>` brings the host and home halves, as today.
- Hyprland and niri share one session kit (shell, lock, idle, wallpaper,
  launcher); each compositor folder holds only what is specific to it.
- Plasma shares only the apps, never the kit: it brings its own shell,
  lock screen, idle handling, night light, wallpaper and launcher.

## Non-goals

- A generic keybind or window-rule abstraction across compositors.
- Changing how hosts pick the personal or work flavour.
- A Plasma version of SDR game mode (`gaming/_sdr-game-mode.nix`).

## Prior art

- [Misterio77/nix-config](https://github.com/Misterio77/nix-config):
  `features/desktop/common/` (anything any desktop uses) and
  `common/wayland-wm/` (waybar, mako, wofi, gammastep … for bare compositors),
  then one folder per desktop. Hyprland imports both tiers, GNOME only
  `common`. This design takes its names.
- One-desktop-per-host configs (luisnquin, nix-alchemy) gate everything on a
  single `desktop` option; rejected below because demon runs several.
- Flat per-desktop modules with nothing shared (alyraffauf): each compositor
  carries its own shell config; rejected because it duplicates the kit.

## Design

### Layout

```
home/common/optional/desktops/
├─ common/                         every desktop, Plasma included
│  ├─ apps/                        dolphin, eog, libreoffice, playerctl, zathura
│  ├─ crash-capture.nix            (open question 1)
│  └─ wayland-wm/                  kit for bare compositors (Hyprland, niri)
│     ├─ idle-lock/                hypridle + hyprlock wiring, oled-care core
│     ├─ wallpaper/                wpaperd + picker
│     ├─ night-light.nix           wlsunset
│     ├─ personal/                 Noctalia (+plugins), walker, hyprlock theme, visuals, wallpaper defaults
│     └─ work/                     waybar, mako, wofi
├─ hyprland/                       Hyprland only
├─ niri/                           niri only
└─ plasma6/                        Plasma only
```

`common/` and `common/wayland-wm/` are reached through the desktop modules'
imports, not as optional modules of their own.

### Move map (from `hyprland/`)

| Today | Goes to | Notes |
|---|---|---|
| `_common/apps/{dolphin,eog,libreoffice,playerctl,zathura}.nix` | `common/apps/` | no Hyprland references |
| `_common/apps/wlsunset.nix` | `common/wayland-wm/night-light.nix` | Plasma has KWin night light |
| `_common/apps/nwg-displays.nix` | stays in `hyprland/` | writes Hyprland monitor config |
| `_common/crash-capture.nix` | `common/` or the kit | open question 1 |
| `_common/{hypridle,hyprlock}.nix`, `_common/oled-care/` | `common/wayland-wm/idle-lock/` | `hyprctl dpms` → dpms option; binds → `_hyprland.nix` |
| `_common/wallpaper.nix` | `common/wayland-wm/wallpaper/` | bind, window rules, reload hook → `_hyprland.nix` |
| `personal/*` | `common/wayland-wm/personal/` | Noctalia binds/layer rules, walker settings, visuals' Hyprland block → `_hyprland.nix` siblings |
| `work/*` | `common/wayland-wm/work/` | waybar/wofi/mako Hyprland lines → `_hyprland.nix` siblings |
| `_common/{settings,binds,lib,monitor-control,pip,screenshots,recovery,btop}.nix`, `_common/plugins/`, `nvidia.nix`, `software-dimming.nix`, `sunshine.nix`, `wlcrosshair.nix` | stay in `hyprland/` | Hyprland only |

### How the kit reaches each compositor

1. **Per-compositor adapter files owned by the feature**, as
   `gaming/_hyprland.nix` already does: `wallpaper/default.nix` holds the
   shared part, `wallpaper/_hyprland.nix` and `wallpaper/_niri.nix` its binds,
   window/layer rules and reload hooks, each under
   `lib.mkIf <that compositor is enabled>`. A feature's binds sit beside it.
2. **One option for runtime commands the kit calls:**
   `desktop.session.dpms.{off,on}`. hypridle and oled-care's idle-dpms both
   need "monitors off/on"; Hyprland sets `hyprctl dispatch dpms off|on`, niri
   `niri msg action power-off-monitors` / `power-on-monitors`.

### Suites

| Suite | Host half | Home half |
|---|---|---|
| `hyprland` | `nixos/desktops/hyprland` | `desktops/hyprland`, importing `common`, `common/wayland-wm`, `wayland-wm/personal` |
| `niri` | `nixos/desktops/niri` | `desktops/niri`, the same three imports |
| `plasma6` | `nixos/desktops/plasma6` | `desktops/plasma6`, importing `common` |

A host with Hyprland and niri imports the shared modules twice; the module
system deduplicates them, so the Noctalia config is defined once. The
personal flavour rides with the suites as today; hosts that use the work
flavour keep composing it themselves.

### Portals

Home Manager's Hyprland module adds xdg-desktop-portal-hyprland to the
per-user profile, and xdg-desktop-portal reads only the first matching config
directory, hiding other desktops' portal setup
([Discourse](https://discourse.nixos.org/t/hyprland-home-manager-module-breaks-portal-discovery-for-other-desktop-environments/78042)).
Portals move to the system side only, one per desktop (Hyprland; GNOME for
niri; KDE), with Home Manager's portal handling off (open question 3).

## Alternatives considered

- **All kit binds in each compositor's `binds.nix`.** Every feature's binds
  would be spread over N compositor folders, and a new kit feature means
  editing each of them.
- **A cross-compositor bind/rule option translated per compositor.** Their
  models differ (Hyprland dispatchers vs niri actions vs KWin shortcuts); with
  two consumers it would guess at a contract.
- **One `desktop` option gating everything per host.** Assumes one desktop
  per host; demon runs several.
- **A single shared layer for every desktop, Plasma included.** Plasma
  replaces shell, lock, idle, night light, wallpaper and launcher, so most of
  that layer would be dead or conflicting there.

## Migration

Each phase preserves behaviour. Verify by byte-identical rendered
`hyprland.conf` and identical user unit names on every host that imports a
desktop (demon, freya, zephy, azuree, rig-pc), compared against a baseline
taken before the phase. Whole home generations differ on any edit (nixvim,
tridactyl and fontconfig embed the repo source path), so compare outputs,
not activation derivations.

1. Move the apps (and crash-capture, once placed) to `common/`; pure moves.
2. Create `common/wayland-wm/`: move the kit modules, splitting their Hyprland
   lines into `_hyprland.nix` siblings.
3. Add `desktop.session.dpms` and point hypridle and oled-care at it.
4. Thin `hyprland/` to what remains; point the hyprland suite's home half at
   it, importing the tiers.
5. niri: `_niri.nix` adapters for the kit pieces; drop niri's own Noctalia
   config; niri's home module imports the tiers. demon then evaluates.
6. Portal fix; live-test screen sharing and file pickers under niri.
7. `plasma6` imports `common`.

Settle folder names with the user before any `git mv` that introduces a name
not in this document.

## Starting state (2026-10-24)

Staged, not yet built:

- `niri` suite in `hosts/common/optional/nixos/desktops/_suites.nix` and
  `home/common/optional/desktops/_suites.nix`; demon imports
  `useSuite suites.niri`.
- niri home module keys outputs by connector (`m.output`), not `m.name`.
- niri host module uses `pkgs.niri` (FLAKE-UPDATE: niri-flake's niri-stable
  pin asks for the removed `libdisplay-info_0_2`).
- demon fails evaluation on `programs.noctalia.package` defined by both
  `hyprland/personal/noctalia` and `niri/`; phase 5 resolves it.

niri now uses nixpkgs' `xwayland-satellite` (0.8.3) rather than niri-flake's older `xwayland-satellite-unstable` (0.8.2).

## Open questions

1. Does crash-capture assume a bare-compositor session? Read it before
   placing it in `common/` or the kit.
2. Should oled-care (wallpaper guard, wear tracker, idle dpms) run under
   Plasma? If so it needs a Plasma adapter rather than living only in the kit.
3. Does `wayland.windowManager.hyprland.portalPackage = null` (or another
   setting) keep Home Manager from adding the Hyprland portal to the user
   profile?
4. Do hypridle and oled-care's wear tracker work against niri's idle and
   output protocols? Check while writing their niri adapters.

## Risks

- Window-rule order changes when rule-bearing modules move; Hyprland lets the
  later rule win only for the same effect, so compare rule order and reason
  about any reordered pair, as done for the gaming split.
- Running the kit under niri for the first time may surface niri-specific
  breakage beyond the four open questions.

## Addendum: migration (2026-10-24)

Phases 1–6 are in the config. The live niri test (phase 6) is still to be done, and phase 7 is on hold. Where this addendum and the text above disagree, the addendum wins.

### What changed from the design

- **Entry points.** `hyprland/personal.nix` and `hyprland/work.nix` are thin files: each imports `_common` plus its kit flavour, so `optional.home.desktops.hyprland.{personal,work}` and the suite keep their names. `common/default.nix` imports only `apps/`, so the kit is reached by import and isn't an optional module.
- **crash-capture** (open question 1) lives in the kit. Its only compositor tie is `walker --dmenu`, the kit's launcher.
- **dolphin** moved from `common/apps/` to the kit. It writes `kdeglobals` and `dolphinrc` read-only, which would fight Plasma and plasma-manager over those files.
- **Adapter gating.**
  - `_hyprland.nix` gates on `wayland.windowManager.hyprland.enable`.
  - `_niri.nix` gates on `options.programs ? niri`. niri-flake injects its Home Manager options only on hosts whose NixOS config imports its module, and that module is anonymous, so the kit can't import it a second time.
  - `mkIf` doesn't hide an undeclared option, so the kit may only set options Home Manager or the kit itself declares. The Hyprland reload hook became `desktop.session.reload.commands`, and the personal PiP styling moved to `hyprland/personal.nix`.
- **visuals.nix** keeps its Hyprland block inline under `mkIf`, because it shares its corner radius with the Noctalia bar.
- **dpms** is `desktop.session.dpms.<XDG_CURRENT_DESKTOP>.{off,on}`, dispatched at runtime by `session-dpms`. demon defines both compositors, and one `hypridle.conf` serves both sessions.
- **Portals** (open question 3): `wayland.windowManager.hyprland.portalPackage = null` turns off Home Manager's portal module, which drops `NIX_XDG_DESKTOP_PORTAL_DIR`. niri-flake's plain `xdg.portal.configPackages` overrode nixpkgs' `mkDefault` Hyprland entry, so the host Hyprland module now sets it at normal priority and the two merge.

### Open question 4, answered

- hypridle 0.1.8 starts on niri: ext-idle-notify is the only protocol it requires. But `inhibit_sleep = 3` needs `hyprland-lock-notify-v1`, and without it sleep goes uninhibited with no fallback (mode 2 falls back). Under niri, locking before suspend is best-effort.
- The OLED wear tracker reads `hyprctl monitors`, so its unit carries `ConditionEnvironment=HYPRLAND_INSTANCE_SIGNATURE` and is skipped under niri until it has a niri reader.

### Phase 7 on hold

`common/apps` makes `mimeapps.list` read-only and sets eog and zathura as defaults. On Plasma hosts that would replace Gwenview and Okular and stop System Settings from saving default apps. Whether zephy and azuree should get it is the owner's call. Open question 2 stays moot while Plasma doesn't import the kit.

### Remaining risks

- niri's config is validated only at build time (`niri validate`), so the new adapters haven't been through it yet.
- The ai-usage check is now named `script:home:wayland-wm:ai-usage`.

## Addendum: Plasma on the same host (2026-10-24)

demon now imports the hyprland, niri and plasma6 suites. Every kit service was `WantedBy=graphical-session.target`, which Plasma starts too, so a Plasma login also ran Noctalia, wpaperd, hypridle/hyprlock, a second polkit agent and the Hyprland gamma tools.

### Decision: a kit target each bare compositor starts

- `bare-compositor-session.target` lives in `common/wayland-wm/` and is `PartOf`/`After=graphical-session.target`.
- Kit services are `WantedBy`/`PartOf` it. The kit sets Home Manager's `wayland.systemd.target` to it, which hypridle, wpaperd, Noctalia and swayosd read; our own units use the same option. Only modules that hard-code `graphical-session.target` with no option (walker, elephant, hyprpolkitagent) are overridden, through `config.lib.waylandWm.startWithSession` and `config.lib.hyprland.startWithHyprland`.
- Each compositor pulls it in from its own unit: niri from `niri.service`, Hyprland from UWSM's `wayland-wm@hyprland.desktop.service`. Plasma never does.
- Compositor-only units start with their compositor's unit instead of a condition. Hyprland's (hyprpolkitagent, hyprsunset, hypr-gamma-schedule, sdr-game-mode, the OLED wear tracker, the Safe Eyes Hyprland guard) use `config.lib.hyprland.sessionUnit`; the Safe Eyes niri guard uses `niri.service`. No `ConditionEnvironment` is left.
- Services may order `After=` the target: systemd skips a target's implicit ordering after a unit that is already ordered after it.

### Vocabulary

- **Kit**: the folder `common/wayland-wm/`, the shared layer for bare compositors (Hyprland, niri).
- **Bare-compositor session**: the kit's running half, the `bare-compositor-session.target`. The name avoids UWSM's `wayland-wm@`/`wayland-session@` units.
- `desktop.session.*` (dpms, reload commands) is declared by the kit, so it exists only on hosts that import it, despite the general-sounding namespace.

### Alternatives rejected

- **Bind each service to every compositor's unit:** every kit service would list every compositor, and adding a compositor would touch them all.
- **`ConditionEnvironment` on `XDG_CURRENT_DESKTOP`:** two lines on every kit service, edited for each new compositor, and skipped units show as failed conditions.
- **Start from the compositor config (`exec-once`/`spawn-at-startup`):** loses systemd restarts, logs and `PartOf` teardown.
- **NixOS specialisations:** the desktop would be picked at boot instead of at the greeter.

### Other fixes for one host running several desktops

- The Plasma module enables SDDM only without greetd. zephy had both login managers enabled; it now uses greetd, which it imports explicitly.
- Plasma's `portals.conf` is added at normal priority, the same `mkDefault` problem as Hyprland's.
- `dolphin.nix` leaves `kdeglobals` to Plasma where Plasma is installed.
- Stylix's Hyprland target was starting hyprpaper alongside wpaperd. It is now off.

### Open

- greetd's PAM starts KWallet on every login, not only Plasma's, so KWallet and gnome-keyring can both claim `org.freedesktop.secrets`. Check in a live session.
- Stylix's KDE/Qt targets stay on, as on azuree. Check that Plasma looks right on demon.

## Addendum: features own their adapters (2026-10-26)

The move map put the personal flavour's compositor lines in `personal/_hyprland.nix` and `personal/_niri.nix`. Those two files mixed Noctalia's and walker's binds and layer rules, so removing either meant editing shared files. Each feature now carries its own: `walker.nix` inline, and `personal/noctalia/_{hyprland,niri}.nix` beside Noctalia's module. Removing a feature is deleting its file or folder and its line in `personal/default.nix`.

Still outside `noctalia/`: the bar's shape in `visuals.nix` (shares the window corner radius), freya's M4 `power-cycle` bind and OLED bar auto-hide in `home/primary/freya.nix`, and the Sunshine drop-in in `hyprland/sunshine.nix`.

The same applies outside the kit (`dolphin.nix`, `tools/wayscriber.nix`, `services/gpu-screen-recorder.nix`). A feature keeps its compositor settings inline under `lib.mkMerge`; a folder with `_hyprland.nix` and `_niri.nix` siblings is only for one already split into a folder, as `noctalia/` is for its plugins. Hyprland settings are not gated, since Home Manager renders them only where Hyprland is enabled; niri binds and Plasma hotkeys are gated on `options.programs ? niri` / `? plasma`, whose options exist only where those modules are imported. Their binds had been in every compositor's binds file, so hosts without the feature got dead keys (freya's SUPER+X ran the absent `save-gsr-replay`).

## Addendum: niri-flake and plasma-manager on every host (2026-10-26)

Supersedes the `options.programs ? niri` / `? plasma` gating above. Feature modules set `programs.niri.settings.*` and `programs.plasma.*` with no gate, like Hyprland settings.

- **niri-flake** is imported for every NixOS host in `hosts/common/core/nixos/niri.nix`; the niri host module only enables it and pins `pkgs.niri`. Its home module has no enable switch and writes `config.kdl` (validated by building it with niri) whenever settings exist, so the core module forces `xdg.configFile.niri-config` off where `programs.niri.enable` is false. Its binary cache is off everywhere: it serves only niri-flake's builds, and we run nixpkgs' niri.
- **plasma-manager** is a home-manager shared module for every NixOS user in `hosts/common/core/nixos/plasma-manager.nix`. Its file writer and hotkeys are gated on `programs.plasma.enable`, so it is inert elsewhere.
- **safeeyes' niri game guard** used the options' existence to mean "this host runs niri"; it now reads `osConfig.programs.niri.enable`.

### Alternatives rejected

- **Import niri-flake's home module globally, keep its NixOS module on niri hosts:** that NixOS module adds the same anonymous home module through `sharedModules`, and a second import fails with "option already declared".
- **nixpkgs' NixOS niri module plus a global niri-flake home module:** loses niri-flake's polkit agent, which niri sessions rely on, and its `defaultSession = mkDefault "niri"` collides with Plasma's on demon.
- **Drop niri-flake for Home Manager's `wayland.windowManager.niri`:** loses typed settings and the stylix niri target, and means rewriting the niri config into untyped KDL attrs.
- **Pass-through options (`desktop.binds.{niri,plasma}`):** a second name for each real option, untyped until it reaches the consumer.

### Open

- Eval time on hosts without niri or Plasma, which now load both option trees. Compare `time nix eval …freya…toplevel.drvPath` against the commit before.
