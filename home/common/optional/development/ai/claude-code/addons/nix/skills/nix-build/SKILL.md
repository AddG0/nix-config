---
name: nix-build
description: Build a Nix flake output, fix errors in a loop until it succeeds. Use after editing Nix files, when a build fails, or when verifying a flake output compiles.
argument-hint: "[target] — flake output to build (default: devShell)"
allowed-tools: Task
---

Build target: `$ARGUMENTS`

Parse the argument to determine the build command:

- No argument or `devshell` → `nix develop --command echo "devShell OK"`
- Any other value → `nix build .#<value>`

Launch a **background** Task agent to perform the build:

- `subagent_type`: `nix-builder`
- `run_in_background`: `true`
- Prompt must include the resolved build command and instruct the agent to run the build, diagnose failures, fix source, and retry until it passes

After launching, inform the user that the build is running in the background and they can continue working.

When reporting the result, only say whether the build succeeded or failed. Do not include the nix store path. If it failed, summarize what went wrong and what was fixed.
