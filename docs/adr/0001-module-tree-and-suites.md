---
status: accepted
date: 2026-09-30
---

# By-name optional module tree and two-sided suites

## Context and Problem Statement

Hosts and homes opt into functionality by importing optional modules, but the two
sides are wired separately: a host imports `hosts/common/optional/nixos/gaming`
while its home separately imports `home/common/optional/gaming`, and nothing keeps
them in sync (azuree's host imported gaming, its home did not). Import lists are
stringly typed (`"nixos/services/openssh.nix"`), and bundle directories hide
opt-in siblings their `default.nix` does not import, so the only way to learn
what exists, or whether something is already included, is to read the tree.

## Decision Drivers

- Opt-in must stay import-based so third-party modules load only where used
  (`imports` cannot depend on `config`).
- One host action should enable both halves of something that spans host and home.
- Home modules stay plain: no flags, no conditional imports.
- Importable modules should be enumerable and typo-safe.
- "Is this already included?" must have one obvious answer.

## Considered Options

1. `addg.*` enable-option tree (every module always imported, gated by `mkIf`).
2. `hostSpec.features.*` flags with conditional home imports.
3. `osConfig` pull (home modules and imports gated on the host's config).
4. `features/<name>/` directories co-locating each feature's halves.
5. Bundle directories with an `extras/` subdirectory for opt-ins.
6. Bundle modules named `core.nix` inside namespaces.
7. By-name module tree plus suites as lists, optionally two-sided.

## Decision Outcome

Chosen option: 7, because it keeps opt-in import-based, keeps every file in its
natural tree (system modules under `hosts/`, user modules under `home/`), makes
bundle membership explicit in one declarative place, and enables a suite's host
and home halves from a single host import.

- **Module tree.** `lib.custom.optional.{hosts,home}` is generated from
  `hosts/common/optional` and `home/common/optional` with the by-name rule used
  for packages: a `.nix` file or a directory containing `default.nix` is a leaf
  (its path); any other directory is a namespace; `_`-prefixed entries are
  private. Import lists reference leaves as attributes
  (`with lib.custom.optional.home.gaming; [heroic minecraft]`), so a typo fails
  with "attribute missing". Anything inside a leaf directory (data, helpers) is
  the leaf's own business.
- **Suites.** A suite names a set of leaves, as `{ nixos = [...]; home = [...]; }`
  with either half optional. Each namespace directory that holds a suite's
  members has a `_suites.nix` returning `{ <suite>.<nixos|home> = [...]; }`, so
  opening a folder shows what its bundle includes: anything in the folder not
  listed there is an add-on. `lib.custom.suites` is generated from every
  `_suites.nix` in the three trees and merged by suite name (defining the same
  half twice is an error); suites can reference each other (`development`
  includes `ide`). `lib.custom.useSuite suite` returns the nixos half plus a
  module that adds the home half to the primary user's home-manager imports, so
  one host import enables both. Standalone homes import `suite.home` directly.
- **Import lists** group leaves by namespace, one `with` block each
  (`(with lib.custom.optional.home.development; [aws gcloud ide.jetbrains-remote])`),
  sorted, with commented-out entries kept in their group.
- **Bundles become suites.** A directory whose `default.nix` only aggregated its
  siblings loses that `default.nix` and becomes a namespace; config that lived in
  it moves to a leaf named for its content, or `core.nix` when it mixes
  several (gaming's became `gaming/core.nix`, secrets' `secrets/sops.nix`). Unlike
  option 6, `core.nix` is an ordinary leaf that its suite lists, not a module
  that imports the others.

### Consequences

- Colocated `_suites.nix` files are our own convention; prior art (digga/devos)
  defines suites centrally. Chosen because a central file left "is this already
  included?" unanswerable from the folder being read.

- Good: host and home halves of a suite cannot drift.
- Good: every importable module is listable and typo-checked; suite membership is
  read in one file.
- Good: third-party modules stay scoped to the leaves that import them.
- Bad: `useSuite` pushes into home-manager, so it requires the home-manager NixOS
  module in the evaluation (true for every host here); it targets the primary
  user only.
- Neutral: standalone `homeConfigurations` exist only for machines without a
  host (`cloud-shell`, `macbook-laptop`); a host's home is the one it embeds,
  suites included, read as
  `nixosConfigurations.<host>.config.home-manager.users.<user>` when needed.
- Neutral: bundles migrate one at a time; until then their `default.nix` keeps
  them as leaves, hiding their inner files from the tree.

## Pros and Cons of the Options

### 1. `addg.*` enable-option tree

- Good: familiar NixOS style; a single flag per feature.
- Bad: third-party modules cannot be imported conditionally, so all would be
  always-imported and every host pays their option declarations.

### 2. `hostSpec.features.*` flags + conditional home imports

- Good: reuses the existing `hostSpec` channel; imports stay lazy.
- Bad: home files gain conditional `imports`; the host side still needs its own.

### 3. `osConfig` pull

- Good: decoupled; works for standalone homes.
- Bad: NixOS-side imports still cannot depend on host config, so it solves half.

### 4. `features/<name>/` directories

- Good: one import enables both halves.
- Bad: a third kind of directory with a judgement call about what belongs there;
  moves files out of their natural trees.

### 5. `extras/` subdirectories

- Good: location says whether a module is opt-in.
- Bad: breaks for extras of baseline members (unreachable or needing special
  traversal) and for data directories inside bundles; deep `.extras.` paths.

### 6. `core.nix` bundle modules

- Good: explicit membership.
- Bad: a magic filename in every namespace and two paths to the same module;
  bundles can only compose by importing each other.
