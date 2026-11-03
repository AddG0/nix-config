---
status: accepted
date: 2026-11-02
---

# Overlay tests live beside their overlays, and `overlays/` holds tests

## Context and Problem Statement

The zsh-completion-sync overlay carries patches that need a regression test.
`checks/discovery.nix` did not read `overlays/`, so the first version of that
suite sat in `home/common/core/cli/shells/tests/` and failed as
`script:home:shells`, naming a home module that has nothing to do with the
patch. `importOverlays` also imported every `.nix` file under `overlays/`, so a
`tests/script.nix` there would have been loaded as an overlay.

## Considered Options

1. `overlays` becomes a discovery root; `importOverlays` skips `tests/`
   folders; a suite sits in `tests/` beside the overlays it covers.
2. Keep overlay suites under the home or host module that uses the package.
3. Put the test in the overridden package's `passthru.tests`, run by
   `checks/packages.nix`.

## Decision Outcome

Chosen: option 1.

- The zsh-completion-sync suite is `overlays/common/development/tests/script.nix`,
  so a failure names `script:overlays:development`.
- A suite imports its overlay by relative path and applies it with
  `pkgs.extend`, so it tests the overlay file itself rather than whatever
  `pkgs` the checks were handed.
- Option 2 rejected: the test sits away from the patch it guards, and the check
  name points at the wrong code.
- Option 3 rejected: `checks/packages.nix` covers only our `pkgs.addg` scope;
  an override of a nixpkgs package is not in it.

### Consequences

- Good: a patch, its overlay and its test are one folder.
- Neutral: adds a fifth qualified root to the roots ADR 0007 lists; its naming
  rules apply unchanged.
- Bad: no folder named `tests` under `overlays/` can hold an overlay.
