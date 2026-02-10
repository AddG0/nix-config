---
name: nix-build
description: Build a Nix flake output, fix errors in a loop until it succeeds.
argument-hint: "[target] — flake output to build (default: devShell)"
context: fork
agent: nix-builder
allowed-tools: Bash, Read, Edit, Glob, Grep
---

Parse the argument to determine the build target:

- No argument or `devshell` → `nix build .#devShells.$(nix eval --impure --expr builtins.currentSystem).default`
- Any other value → `nix build .#<value>`
