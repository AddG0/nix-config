---
status: accepted
date: 2026-10-20
---

# How code-assistant-profiles maps features onto Claude Code, Codex and opencode

## Context and Problem Statement

`modules/home/programs/code-assistant-profiles` holds one tool-agnostic
description of skills, agents, rules, commands, MCP and LSP servers, and
renders it for Claude Code, Codex and opencode. A docs audit on 2026-10-20
(Claude Code 2.1.303, codex-cli 0.163.0, opencode 1.19.0) found it trails all
three: no hooks anywhere, dozens of optional fields missing, Codex subagents
flattened into skills. Closing that needs four decisions about where features
live and how strictly they are typed. The gap list and the build order are in
`docs/work/assistant-config-gaps/plan.md`.

## Decision Drivers

- Cover every feature each tool documents, not just the overlap.
- Typos should fail at evaluation, not load silently and do nothing.
- Three tools that ship weekly; every typed field is upkeep.
- Home Manager writes only under `$HOME`.

## Considered Options

Hooks:

1. Per-tool typed hooks covering every event and handler type of each tool.
2. One shared hook type for the events all three share, translated per tool.

Optional fields:

3. Type fields found in two or more tools in the shared layer; tool-only
   fields go through a per-target `extra` passthrough.
4. A typed option for every documented field of every tool.

Claude Code managed tier (`/etc/claude-code`):

5. Leave it unsupported.
6. Add a NixOS/darwin module that writes it.

Codex writable `config.toml`:

7. Use upstream Home Manager's `programs.codex.mutableSettings`.
8. Keep our `mutableConfig` and `merge-program.nix`.

## Decision Outcome

Chosen: 1, 3, 5 and 7.

- **Hooks, option 1.** A hook's output is tool-specific (Claude's
  `hookSpecificOutput`, Codex's own shape, opencode's JS plugin API), so a
  shared definition still needs per-tool commands. Per-tool options reach all
  33 Claude events and 5 handler types, all 12 Codex events, and opencode
  plugins. Option 2 reaches only the shared subset.
- **Optional fields, option 3.** Cross-tool fields such as MCP `timeout` and
  `enabled` get one validated definition. Tool-only fields (Claude agent
  `isolation`, opencode `temperature`) pass through `extra` without
  validation. Option 4 means roughly 60 options to keep in step with three
  release trains.
- **Managed tier, option 5.** These are single-user machines, and nothing
  needs org-enforced policy. Option 6 adds a module tree across both system
  module systems for no current use.
- **Codex config, option 7.** Upstream does the same `$dynamic * $static`
  merge we hand-wrote. Before deleting ours, confirm upstream's merge matches
  ours on the cases in `modules/home/programs/codex/tests.nix`.

### Consequences

- Good: every documented hook event is reachable and validated per tool.
- Good: one definition for cross-tool fields; less code once `mutableConfig`
  is gone.
- Bad: a hook wanted in two tools is declared twice.
- Bad: typos in `extra` fields load silently; the tool ignores unknown keys.
- Bad: Codex merge behaviour follows upstream releases.
- Neutral: the managed tier can be added later without touching user scope.
