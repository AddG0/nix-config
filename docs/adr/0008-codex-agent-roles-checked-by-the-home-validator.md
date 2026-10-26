---
status: accepted
date: 2026-10-26
---

# Codex agent roles are checked by the home validator, not per role

Supersedes in part [ADR 0007](0007-test-kinds-harness-and-checkphase-validation.md):
option 10 no longer applies to Codex agent roles. Claude plugin directories
and Prismantis `pluginDirs` keep their per-artefact checks.

## Context and Problem Statement

ADR 0007 chose option 10 for a Codex agent role: each `agents/<name>.toml`
derivation ran `codex doctor --json` on that one role, behind
`programs.code-assistant-profiles.targets.codex.checkConfig`. At the time the
whole-tree validators ran only under `nix flake check`, so this was the only
way a role Codex cannot read failed the build.

ADR 0007's addendum then moved the whole-tree validators into Home Manager's
`home.checks`, which build with every `home-manager switch` and host rebuild.
The Codex validator's own `codex doctor --json` run loads every role in
`agents/`, and the `codex-agent` fixture already shows it rejecting a broken
one. Each build ran `codex doctor` once per role and once more in the
validator.

## Considered Options

1. Keep both: the per-role derivation check and the validator.
2. Drop the per-role check; the validator alone covers roles.

## Decision Outcome

Chosen: option 2.

- `targets/codex/agent-check.nix` and the `targets.codex.checkConfig` option
  are gone; `programs.code-assistant-profiles.checkConfig` still switches the
  validators off. `config-load.jq`, now read only by the validator, moved into
  `targets/codex/validator/` with it.
- Option 1 rejected: it found nothing the validator misses and cost one
  `codex doctor` run per role on every build.
- Cost: a broken role no longer fails its own TOML derivation. The failure
  comes from the home's `assistant-config-check` and still names
  `agents/<name>.toml`.
