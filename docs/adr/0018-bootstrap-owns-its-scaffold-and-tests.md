---
status: accepted
date: 2026-10-31
---

# `just bootstrap` keeps its scaffold and tests beside the script, and `scripts/` holds tests

## Context and Problem Statement

`just bootstrap` (ADR 0017) creates a new host from starter files and is
tested by a `script` suite. Both lived in `hosts/templates/`: next to
`hosts/nixos/` it read as a kind of host, and the check that failed for a
script bug was named `script:hosts:templates`. `checks/discovery.nix` did not
read `scripts/`, which is why the tests sat under `hosts/`.

## Considered Options

1. `scripts/bootstrap/` holds the script, its scaffold and its tests; `scripts`
   becomes a discovery root.
2. Keep `hosts/templates/` and rename it, for example `hosts/scaffold/`.
3. Keep the files where they are and explain them in the docs.

## Decision Outcome

Chosen: option 1.

- `scripts/bootstrap/scaffold/host/` is what becomes `hosts/nixos/<host>/`;
  `scaffold/disko.nix` is added beside it for a wiped disk. The host part has
  its own folder because its `default.nix` imports every `.nix` file next to
  it.
- The suite is `scripts/bootstrap/tests/script.nix`, so a failure names
  `script:scripts:bootstrap`.
- Option 2 rejected: the tests still could not live with the script they test.
- Option 3 rejected: the check name and folder would keep pointing away from
  the script.

### Consequences

- Good: everything `just bootstrap` owns is one folder.
- Neutral: adds a fourth qualified root to the roots ADR 0007 lists; its
  naming rules apply unchanged.
- Bad: the template checks in `checks/configurations.nix` reach into
  `scripts/`.
