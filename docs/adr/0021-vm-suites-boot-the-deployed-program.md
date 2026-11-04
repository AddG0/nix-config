---
status: accepted
date: 2026-11-03
---

# `vm.nix` suites boot the deployed program in a NixOS test

## Context and Problem Statement

VS Code's `settings.json` is a read-only store link. The Postman extension
reads `chat.instructionsFilesLocations` (VS Code merges its own default keys
into what it returns) and writes the merged object back, so the write fails
with EROFS and the file stays dirty in the editor. Nothing in `just check`
could see it: the bug lives in what a third-party extension does at runtime,
and VS Code's core defaults are not in any file a Nix test can read.

## Considered Options

1. A fifth test kind, `vm.nix`: a `pkgs.testers.runNixOSTest` that boots the
   real VS Code with every host's real profile and fails on any write to a
   managed user file.
2. A Nix eval test that every object setting already holds VS Code's and the
   extensions' default keys, in their order.
3. A `just` diagnostic that reads VS Code's logs and its `Backups/` buffer on
   the desktop after a failure.

## Decision Outcome

Chosen: option 1.

- The VS Code suite is `home/common/optional/development/ide/vscode/tests/vm.nix`,
  named `vm:home:vscode`. It takes the profiles from `self.nixosConfigurations`,
  boots each distinct one in turn with writable copies of the managed user
  files, and fails on any diff against the generated file. Diffing the write
  itself, not grepping VS Code's "Unable to write file" log line, means a
  reworded log message cannot turn the check silently green.
- `vm` checks exist only on Linux systems, and are not wrapped with
  `overrideAttrs`, which a NixOS test lacks.
- Option 2 rejected: core defaults exist only as minified constants in
  `workbench.desktop.main.js`, and `--export-default-configuration` does
  nothing in release builds, so the defaults would be a hand-kept fixture that
  drifts and covers only the settings someone thought of.
- Option 3 rejected: it explains a failure after it reached the desktop instead
  of stopping it before deploy.

### Consequences

- Good: any extension rewriting any managed user file fails `just check`,
  with the keys it wanted.
- Bad: `just check` boots one VM per distinct profile, each with VS Code and
  every extension; minutes, not seconds.
- Bad: an extension that writes only on an activation event the empty VM never
  fires (opening a given file type) slips through.
- Neutral: supersedes the planned `host` kind in ADR 0007 for runtime
  behaviour; ADR 0007's naming rules apply unchanged.
