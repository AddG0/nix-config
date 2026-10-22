---
status: accepted, superseded in part by ADR 0007
date: 2026-10-21
---

# Assistant config checks evaluate each host's home config and run the tools' own validators

## Context and Problem Statement

Claude Code, Codex and opencode reject some configs only when they start: an
opencode agent colour outside its enum, a Codex hook missing `command`, a
Claude plugin manifest without `name`. Module tests catch what our own
options type, but a host's real files also come from addons, `extraFiles`,
`pluginDirs` and upstream Home Manager options we do not type. The question
was what a flake check should validate, and with what.

## Decision Drivers

- A config the tool would reject must fail `nix flake check`.
- Check what each host actually writes, not a fixture standing in for it.
- The tool's own parser is the ground truth; three tools ship weekly.
- `nix flake check` must stay fast enough to run before every switch.

## Considered Options

1. One check per host, built from that host's evaluated home config, running
   each tool's own validator over the files it writes.
2. Fixture-only module tests through the same validators.
3. Validate the host's `activationPackage` or `home-files` output.
4. Validate against published JSON schemas (SchemaStore's
   claude-code-settings, opencode's `config.json`).
5. Validate in a home-manager activation step.

## Decision Outcome

Chosen: option 1, with option 2's fixtures as its regression test.

- **Option 1** sees every file the host writes, from any module, and uses the
  installed tool versions. It costs one evaluation of each host's home
  config per `nix flake check` (about 20 s on demon), plus a second
  evaluation through `extendModules` with Codex `mutableSettings` off, since
  that mode keeps `config.toml` out of `home.file`.
- **Option 2** alone misses everything outside our typed options, which is
  where the untyped bad values come from. Kept to prove the check fails.
- **Option 3** builds every home file of the host (editor extensions,
  themes), minutes instead of seconds, to read a few dozen of them.
- **Option 4** lags the tools, covers only some files (no Codex agents, no
  opencode markdown agents), and is someone else's reading of the parser.
  Claude's `doctor` validates settings offline, so no schema was needed.
- **Option 5** fails at switch time, after the bad config is committed, and
  can leave a half-activated generation.

### Consequences

- Good: a bad value from any module fails before switching, naming host,
  tool, file and the tool's message.
- Good: a tool bump is checked by the version that will run it.
- Bad: `nix flake check` evaluates every assistant-using host's home config,
  twice; adding hosts adds evaluation time.
- Bad: the check reads tool output, `claude doctor`'s `Invalid settings`
  heading and `codex doctor --json`'s `config.load` row; a format change
  either fails the check (missing `config.load` or doctor heading) or is
  caught by the regression fixtures, for the tool version those use.
- Neutral: hosts of another system are skipped; ghost is checked only on
  aarch64-darwin.
