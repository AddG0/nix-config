---
status: accepted
date: 2026-10-07
---

# Home modules are grouped by domain, not by platform

## Context and Problem Statement

Some home modules only work on one platform: omniwm, sketchybar and the
wallpaper rotation are macOS-only, Hyprland and Plasma are Linux-only. Once
darwin had several of them, the question was whether `home/common/optional`
should gain `darwin/` and `nixos/` folders the way `hosts/common/optional`
has, or keep grouping by what a module is for.

## Decision Drivers

- A module should be found by what it does (`just optional`, the tree).
- Modules on different platforms share data: the Linux wpaperd rotation and
  the macOS wallpaper cycle both read `desktops/_wallhaven.nix`.
- Importing a module on the wrong platform must fail at evaluation, not
  silently misbehave.
- Home Manager is one module system on every platform; nix-darwin and NixOS
  are two.

## Considered Options

1. Domain tree; platform-bound modules assert their platform.
2. Platform folders under `home/common/optional` (`darwin/`, `linux/`).
3. Platform folders inside each domain (`desktops/darwin/`, `services/linux/`).

## Decision Outcome

Chosen option: 1. Folders name a domain. A module that only works on one
platform says so with `lib.hm.assertions.assertPlatform`, which fails the
build when it is imported elsewhere. A desktop environment is itself a domain,
so it gets a namespace named after the environment even when that name is an
OS: `desktops/macos/` holds the Mac desktop (omniwm, wallpaper-cycle, and
sketchybar as an add-on) beside `desktops/hyprland/` and `desktops/plasma6/`,
with a `macos` suite like theirs.

`hosts/common/optional` keeps its `nixos/` and `darwin/` split, because those
are different module systems whose options cannot be imported across.

### Consequences

- Good: one place to look per domain; shared data such as `_wallhaven.nix`
  sits beside every module that reads it.
- Good: a wrong-platform import fails with a named assertion.
- Bad: a module's platform is not visible in its path; read its assertion or
  its suite.
- Neutral: `desktops/macos` reads like a platform folder. It is one because
  the desktop it configures only exists on that platform, not because of a
  rule to split by OS.

## Pros and Cons of the Options

### 2. Platform folders under `home/common/optional`

- Good: platform is obvious from the path.
- Bad: every domain (`desktops`, `services`, `development`) is split in two,
  and cross-platform modules have no home.
- Bad: shared data like `_wallhaven.nix` has to live outside both halves.

### 3. Platform folders inside each domain

- Good: keeps domains together at the top level.
- Bad: duplicates what `assertPlatform` already enforces, and modules that run
  on both platforms still have no obvious folder.
