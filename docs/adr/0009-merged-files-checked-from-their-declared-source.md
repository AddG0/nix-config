---
status: accepted
date: 2026-10-26
---

# Files merged at activation are checked from their declared source, not a re-evaluated home

Supersedes in part [ADR 0006](0006-assistant-config-checks-evaluate-hosts.md)
(the second evaluation through `extendModules`) and the
[ADR 0007](0007-test-kinds-harness-and-checkphase-validation.md) addendum
(a validator's `staticConfig`).

## Context and Problem Statement

Under Codex's `mutableSettings`, upstream Home Manager's `programs.codex`
leaves `config.toml` out of `home.file`. The declared content exists only in
a `let` binding, interpolated into the activation script that merges it. The
validator got it back by re-evaluating the whole home through
`extendModules` with `mutableSettings` forced off.

ADR 0006 accepted that second evaluation while it ran only under
`nix flake check`. The ADR 0007 addendum moved the validators into
`home.checks`, so every rebuild paid for it. Profiling freya on 2026-10-26
measured about 10 M of 62 M function calls, roughly 15 s of a 64 s
evaluation.

## Considered Options

1. Keep `staticConfig` and `extendModules`.
2. Our `programs/codex` owns the merge. A new `programs.codex.writableConfig`
   leaves upstream in its immutable mode, which declares `config.toml` in
   `home.file`. Our module disables that entry and merges its source at
   activation, as it already did for `<profile>.config.toml`. A validator
   lists the files its tool merges (`mergedFiles`), and the check links
   their declared source.
3. Vendor upstream `programs/codex`, changed to keep the entry in `home.file`,
   disabled.
4. Read the source path out of the activation script, or call upstream's
   module function again with `mutableSettings` off.
5. Home Manager's `home.file.<name>.mutable` (PR #9921).
6. Codex's read-only system layer, `/etc/codex/config.toml`.
7. Run the validators only under `nix flake check` again.

## Decision Outcome

Chosen: option 2.

- Option 1 rejected: a second evaluation of the whole home on every rebuild,
  only to read one file.
- Option 3 rejected: upstream treats the file as internal and is not expected
  to declare it, so the copy is permanent. That means the whole module
  (466 lines) is hand-synced on every bump, where option 2 copies one merge
  rule.
- Option 4 rejected: a path matched out of a string loses its context, so the
  check would not depend on the file. Restoring it needs `storePath`, which
  pure evaluation forbids, or `appendContext`. Either way the check depends
  on the wording of upstream's script or on the shape of its
  `mkIf`/`mkMerge` output.
- Option 5 rejected: it is still open, and it overwrites the copy on every
  activation, which drops the project trust Codex writes.
- Option 6 rejected: it is system-wide, a Home Manager module cannot write
  it, and it ranks below the user `config.toml`, so stale keys there would
  beat declared ones.
- Option 7 rejected: it gives up the per-rebuild check that the ADR 0007
  addendum chose.

### Consequences

- Good: a home is evaluated once. The check still reads every file Codex
  loads, including `<profile>.config.toml`.
- Bad: `modules/home/programs/codex` carries a copy of upstream's MCP
  transport rule. A fixture with a stale HTTP key beside a declared stdio
  command guards it, but a rule upstream adds later reaches us only by hand.
- Bad: upstream's own `mutableSettings` and `writableConfig` exclude each
  other, and an assertion says so.
- Bad: `mergedFiles` must list every file the tool's module disables for an
  activation merge. A missing one leaves that file unchecked. A unit test pins
  the Codex list, and a probe fixture checks that run-validators links a
  merged file and leaves an unlisted disabled one out.
- Bad: `writableConfig` needs something for `config.toml` to hold. With
  nothing, upstream declares no entry, and evaluation fails naming the
  undefined `source`.
