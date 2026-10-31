---
status: accepted
date: 2026-10-30
---

# A user tree's module rides along with the shared home module at its place

## Context and Problem Statement

Zen's shared module carried the primary user's pins, spaces and containers, so
any other user importing it got them. Splitting those into
`optional.primary.browsers` left every host file importing two modules that
must always travel together, and `development.aws` already had the same
pairing. A forgotten second import goes unnoticed: the browser just comes up
without the user's setup.

A home module can't pick the importing user's extras itself. Home Manager
builds every user from one `submoduleWith` whose `specialArgs` (`lib`,
`osConfig`, `extraSpecialArgs`) are the same for all of them
(`nixos/common.nix:25-34`); the user is only `name`, a `_module.args` value,
and `imports` that read `name` or `config` recurse infinitely.

## Considered Options

1. Expand the imports where a user's import list is built: their host file
   (`home/<tree>/<host>.nix`), their `home/<tree>/common/core`, and each suite
   half `useSuite` hands them. Each shared `optional.home.<path>` leaf also
   brings `optional.<tree>.<path>` when that leaf exists.
2. Import every user-tree module everywhere, gated with `mkIf` on a marker the
   shared module sets, or on `home.username`.
3. Invert it: the user module imports the shared one, hosts import the user
   module, and a check fails a host importing a shared leaf that has a user
   half.
4. A `_suites.nix` pair per shared module.

## Decision Outcome

Chosen: option 1.

- Option 2 rejected: `mkIf false` still needs every option it sets declared,
  so the user half fails to evaluate wherever the shared module is absent; it
  can't gate `imports` either, and every user's modules evaluate in every home.
- Option 3 rejected: importing the shared module alone becomes an error rather
  than doing the right thing, and every host file names the user tree. It does
  need no module rewriting and covers downstream extenders.
- Option 4 rejected: a suite per module is the same two-line pairing moved
  into another file.

### Consequences

- Good: importing a shared module is the whole choice; the user's half follows
  from host files, user core and suites alike.
- Good: a unit test fails when a user tree has a module where the shared tree
  has a namespace, or the reverse, so a half that can never pair is caught.
- Bad: a shared module importing another shared module brings no extras;
  covering it would mean re-collecting modules ourselves. Shared modules must
  not import a leaf that has a user half.
- Bad: downstream extenders of `hosts/nixos/base` build their own import lists,
  so they wrap them in `lib.custom.withUserExtras "<tree>"` to get halves.
- Neutral: rewriting a user file keeps its path as the module `key`, so an
  explicit import of the same file still deduplicates.
