---
allowed-tools: Bash, Read, Glob, Grep, Edit, Task
description: Build a Nix flake output, fix errors in a loop until it succeeds.
user-invocable: true
argument-description: "[target] — flake output to build (default: devShell)"
---

Parse the argument to determine the build target:

- No argument or `devshell` → `nix build .#devShells.$(nix eval --impure --expr builtins.currentSystem).default`
- Any other value → `nix build .#<value>`

Hand off to the **nix-builder** agent with the resolved build command. Do not attempt the build yourself — the agent handles the build-fix loop.
