---
status: accepted
date: 2026-10-08
---

# Linux-style app shortcuts on macOS come from Karabiner-Elements

## Context and Problem Statement

The Linux hosts use Ctrl for app shortcuts (copy, paste, tabs, word jumps), and
terminals keep raw Ctrl. On the Mac keyboard the Linux layout lines up as
Ctrl → Ctrl, Super → Option, Alt → Command, and window-manager binds already sit
on Option through OmniWM. The physical Ctrl key needed to drive app shortcuts
everywhere except terminals.

## Decision Drivers

- Terminals must keep raw Ctrl (Ctrl+C interrupts).
- Option is Super and stays untouched (OmniWM, skhd, Sol).
- The rule set should be maintained by someone other than us.
- Reproducible from the flake, apart from macOS's one-time approval prompts.

## Considered Options

1. Karabiner-Elements, installed from Homebrew, with the karabiner-windows-mode rules filtered for this layout.
2. kanata plus kanata-vk-agent for per-app switching.
3. A global Ctrl↔Cmd swap through nix-darwin `system.keyboard.userKeyMapping`.

## Decision Outcome

Chosen option: 1. Karabiner can make exceptions per app by bundle ID, and
[karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode)
already covers Ctrl shortcuts, Home/End and word movement, excluding
terminals, IDEs and VMs. Its rules assume a PC keyboard (Alt = Option,
Win = Command), so the rules that fire on Option or Command are dropped or
rewritten. The cask comes from Homebrew because the nix-darwin
`services.karabiner-elements` module starts `karabiner_grabber`, which
Karabiner 15 replaced with `Karabiner-Core-Service`.

### Consequences

- Good: Linux Ctrl shortcuts work in GUI apps; terminals get Ctrl+Shift+C/V copy/paste.
- Good: the rule list is pinned upstream JSON plus a jq filter, not hand-written rules.
- Bad: needs a DriverKit extension and Input Monitoring approved by hand once.
- Bad: an upstream bump can rename rules; the filter fails the build when a rule it expects is missing.
- Neutral: VS Code, Zed and JetBrains stay excluded and need Linux keymaps of their own.

## Pros and Cons of the Options

### 2. kanata plus kanata-vk-agent

- Good: the same remapper could replace keyd on Linux.
- Bad: needs the Karabiner driver anyway, kanata running as root, and an
  app-watching helper from a third-party tap; every rule is ours to write.

### 3. Global Ctrl↔Cmd swap

- Good: no driver and no per-app rules; fits `keyboard.nix`.
- Bad: no per-app exceptions, so Ctrl+C in Ghostty copies and interrupting
  moves to the Command key; Ctrl+arrows become line jumps, not word jumps.
