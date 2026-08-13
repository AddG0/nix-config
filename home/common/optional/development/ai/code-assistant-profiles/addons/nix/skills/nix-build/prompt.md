---
description: Build a Nix flake output, fix errors in a loop until it succeeds. Use when explicitly requested, when a build fails, or when verifying a flake output compiles.
argument-hint: "[target] - flake output to build (default: devShell)"
allowed-tools:
  - Agent
---

Build target: `$ARGUMENTS`

Parse the argument to determine the build command:

- No argument or `devshell` -> `nix develop --command echo "devShell OK"`
- Any other value -> `nix build .#<value>`

Spawn a subagent with the **`Agent`** tool to perform the build:

- `subagent_type`: `nix-builder`
- `description`: a short label, e.g. "nix build <target>"
- `prompt`: must include the resolved build command and instruct the agent to run the build, diagnose failures, fix source, and retry until it passes

Subagents already run in the background — there is no `run_in_background` parameter on `Agent` (that belongs to `Bash`), and passing one is a validation error.

After launching, inform the user that the build is running in the background and they can continue working.

When reporting the result, only say whether the build succeeded or failed. Do not include the nix store path. If it failed, summarize what went wrong and what was fixed.
