# Linux-style keybinds on macOS (Karabiner-Elements)

## Goal

Physical keys do what they do on the Linux hosts. On a Mac keyboard the Linux
layout lines up as Ctrl → Ctrl, Super → Option, Alt → Command:

- Ctrl+C/V/X/Z/A/S/F/T/W…, Home/End, Ctrl+arrows and Ctrl+Backspace act as on Linux in GUI apps.
- Terminals still get raw Ctrl (Ctrl+C interrupts); Ctrl+Shift+C/V copy and paste there.
- Option stays Super for OmniWM, skhd and Sol.

## Non-goals

- Window-manager binds: already on Option in `omniwm/default.nix`.
- Linux Alt+⟨letter⟩ binds beyond Alt+F4: none in use yet.
- Editing rules from the Karabiner GUI: Nix owns the rule list.

## Design

### Rule source

The generated `json/windows_shortcuts.json` from
[rux616/karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode),
pinned at `289c4d5444b03347e4d99d75a9f0b99f0ce42fca` with `fetchurl`. A
`runCommand` uses jq to filter it into a rules file, with no IFD.

Upstream assumes a PC keyboard (Alt = Option, Win = Command), so the filter changes these rules:

| Upstream rule | Action | Reason |
|---|---|---|
| 40 Ctrl rules, Home/End, F1, F3, `/ (Ctrl)` | keep | layout-independent |
| `C/V (Ctrl+Shift) [Only Terminal Emulators]` | keep | Linux terminal copy/paste |
| `Insert (Ctrl)`, `Insert (Shift)` (plain) | drop | README: use one variant; keep the `[+Terminal Emulators]` ones |
| `Tab (Alt)` | drop | fires on Option (Super); Command+Tab already sits in the Alt position |
| `F4 (Alt)` | rewrite `from` to Command | Alt+F4 → Cmd+Q from the Alt-position key |
| `Win …`, `L (Win) …` | drop | fires on Command (Alt); Command+L is the browser address bar |
| `L (Alt+Ctrl) …` | drop | Option is Super; lock moves to an Option bind later |
| `1–9 (Cmd) [Open … Dock app]` | drop | Command is Alt; it would hijack Cmd+1–9 browser tabs |
| `Space (Ctrl)` | drop | sends Cmd+Space; the Spotlight hotkey is disabled in `sol.nix` |
| `H/L (Ctrl) [Only Web Browsers]` | keep, add `^app\.zen-browser\.zen$` | Zen is missing from upstream's browser list |

### Files

1. `hosts/common/optional/darwin/desktops/macos/karabiner.nix`: `homebrew.casks = ["karabiner-elements"]`.
   The nix-darwin `services.karabiner-elements` module is broken with nixpkgs 15.7.0: it starts
   `karabiner_grabber`, which the package replaced with `Karabiner-Core-Service.app`.
2. `hosts/common/optional/darwin/desktops/_suites.nix` (new): `macos.nixos = [karabiner]`, so
   `useSuite suites.macos` on ghost pulls it in.
3. `home/common/optional/desktops/macos/karabiner.nix`: the filtered-rules derivation, plus an activation
   step modelled on `solConfig` in `sol.nix`. It sets `.profiles[selected].complex_modifications.rules`
   in `~/.config/karabiner/karabiner.json`, or creates a one-profile file if none exists. Darwin platform assertion.
4. `home/common/optional/desktops/macos/_suites.nix`: add `karabiner`.
5. `docs/adr/0004-…`: Karabiner over kanata and over a global Ctrl↔Cmd swap. Written just before step 1.

### One-time manual steps (not automatable)

- Approve the Karabiner DriverKit system extension in System Settings → General → Login Items & Extensions.
- Grant Input Monitoring to `karabiner_grabber`/Core-Service and the event viewer.

## Verification

- `nix eval` the darwin config, then build the rules derivation and check `jq '.rules[].description'` against the table.
- After the switch, use Karabiner-EventViewer to check that physical Ctrl+C in Zen sends Cmd+C, and in Ghostty sends Ctrl+C.
- Check Option+H (OmniWM focus), the Option tap (Sol) and Alt-position Cmd+Tab still work.

## Open questions

- **Caps Lock → Escape:** it's set through `userKeyMapping` in `hosts/common/core/darwin/system/keyboard.nix`.
  Karabiner grabs the keyboard, and it's unverified whether hidutil mappings survive that. If they don't,
  add a `caps_lock → escape` simple modification to the profile.
- **Does Karabiner rewrite `karabiner.json` from memory, like Sol?** If it does, the activation step stops
  `Karabiner-Core-Service` before merging, the way `solConfig` does.
- ~~Upstream excludes VS Code, Zed and JetBrains.~~ Decided 2026-10-08: keep them excluded; they get Linux keymaps of their own.

## Risks

- Upstream rule descriptions change on a bump, so the drop list silently stops matching. Mitigation: the derivation
  fails when any description it expects to drop or rewrite is missing.
- Every app not in the exclusion lists gets Ctrl rewritten. Electron apps with their own Ctrl binds (Slack, Discord)
  may lose them.
