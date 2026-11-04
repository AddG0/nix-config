---
status: accepted
date: 2026-11-04
---

# User home trees are their own test roots, named under the user

## Context and Problem Statement

`home/<user>/` mirrors `home/common/`, so a user module often shares its leaf
name with the shared one it builds on (`ssh`, `git`). Discovery named both
`script:home:ssh` and threw on the duplicate. The shared ssh suite had dodged
this by importing the primary user's modules into its own fixture, so a test of
shared code depended on one user's config.

## Considered Options

1. Each `home/<user>/` is a discovery root qualified `home:<user>`; the `home`
   root excludes those folders.
2. Give the user module a name of its own (`ssh-credentials`).

## Decision Outcome

Chosen: option 1.

- `checks/tests.nix` builds one root per folder under `home/` other than
  `common`; roots take an `exclude` list so no test is found twice.
- Shared suites under `home/common/` evaluate only shared modules. A user suite
  evaluates the shared modules plus that user's own.
- Option 2 rejected: the module's name stops mirroring its shared sibling, and
  every later same-named pair hits the same collision.

### Consequences

- Good: a user's check name says whose config failed
  (`script:home:primary:ssh`).
- Neutral: the naming rules of ADR 0007 apply unchanged; the qualifier gains a
  segment.
- Bad: `script:home:ai-usage` is now `script:home:primary:ai-usage`.
