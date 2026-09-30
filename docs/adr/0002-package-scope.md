---
status: accepted
date: 2026-09-30
---

# Our packages as one scope, `pkgs.addg`

## Context and Problem Statement

Our packages were merged into nixpkgs' top level by an overlay (`mergePackage`
over ~45 names). A nixpkgs update added a throwing `themes` alias that collided
with ours and broke evaluation, and any importer of our modules had to apply the
overlay to get the packages those modules reference. Temporary fixes to our own
packages lived inside the package files, where they block `update-packages`.

How should our packages reach our config and importers, and how are they patched?

## Decision Drivers

- No name collisions with nixpkgs, now or after future updates.
- Exported modules must work for importers with no overlay and a stock `lib`.
- Packages must build against the evaluating host's own `pkgs`, so
  module-added overlays (e.g. Jovian's steam) apply.
- Modules must not depend on the repository layout (`../../pkgs/...`).
- Temporary fixes must stay in `overlays/` and be checkable against the
  unpatched package.

## Considered Options

1. Keep the top-level overlay, skipping names whose nixpkgs value throws
   (`tryEval`).
2. Plain overlay (`//`) with explicit merges for the few collisions.
3. Flake outputs only; modules read `self.legacyPackages.${system}`.
4. A shared `_module.args.customPkgs` set by the exported modules.
5. Modules `callPackage` their package by relative path (sops-nix style).
6. One namespaced scope, `pkgs.addg`, built with
   `lib.packagesFromDirectoryRecursive` from `pkgs/by-name`; exported modules
   receive it through `importWithLocal`.

## Decision Outcome

Chosen option: 6.

- `pkgs/by-name` holds every package (`<name>/package.nix` or `<name>.nix`;
  directories nest as scopes, shared builders are scope members).
  `pkgs/packages.nix` builds the scope; `overlays/packages.nix` exposes it as
  `pkgs.addg`; the flake exports it as `legacyPackages` (nested) and `packages`
  (flat).
- Private config reads it as the `customPkgs` argument (set in
  `hosts/common/users` and `home/flake-module.nix`).
- Exported modules that need it are curried
  (`{customPkgs, customLib, ...}: module`) and registered with `importWithLocal`,
  which applies `pkgs/packages.nix` to the evaluating `pkgs` (preferring
  `pkgs.addg` when the importer applied our overlay).
- Temporary fixes are overlays in `overlays/`
  (`addg = prev.addg.overrideScope …`); `check-workarounds` builds the unpatched
  scope via `CHECK-CUSTOM-ATTR:`.

### Consequences

- Good: one name (`addg`) can collide with nixpkgs instead of ~45.
- Good: importers need neither our overlay nor our `lib`.
- Good: adding a package is creating `pkgs/by-name/<name>/package.nix`.
- Bad: a package argument named like one of ours resolves to ours inside the
  scope (why `tmuxPlugins` became `tmux-plugins`).
- Bad: `legacyPackages` must drop the scope's helper functions, or the
  `packages` helper breaks `.#packages.<system>` lookups.

## Pros and Cons of the Options

### 1. Top-level overlay with `tryEval`

- Good: smallest change.
- Bad: silently shadows any nixpkgs package that throws; importers still need the
  overlay.

### 2. Plain overlay with explicit merges

- Good: common (Misterio77); no automatic merge logic.
- Bad: still ~45 top-level names that nixpkgs can collide with; importers still
  need the overlay.

### 3. `self.legacyPackages` in modules

- Good: no overlay at all (Mic92).
- Bad: builds against the flake's own `pkgs`, ignoring host overlays (steam lost
  Jovian's changes); `self` in an exported module is the importer's flake.

### 4. `_module.args.customPkgs` from exported modules

- Good: short call sites.
- Bad: a generic module-argument name can collide with an importer's.

### 5. Relative `callPackage` in modules

- Good: the most common pattern (sops-nix); host `pkgs`, no overlay.
- Bad: moving a package or a module breaks the path.
