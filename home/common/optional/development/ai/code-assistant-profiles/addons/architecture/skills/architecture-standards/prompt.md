---
name: architecture-standards
description: "How we structure code: bounded contexts, thin edges, domain types, rules enforced by tests. Use when designing a feature, a module or its interface, or reviewing a design."
---

# Architecture Standards

What holds across our codebases. A repo's own `CLAUDE.md` and rules carry its stack-specific
layout (package tree, layer names, enforcing test names) and win where they are more specific.
For depth, seams and adapters, use the vocabulary in the `codebase-design` skill.

## Principles

1. **Split by bounded context, never by technical layer.** The top level is capabilities
   (`folders/`, `billing/`), not `controllers/` and `services/`. No `shared/`, `common/`,
   `util/` or `kernel/` bucket: a business object lives with the context that owns it.
2. **A context shows a small public surface and hides the rest.** Callers see its API; its
   internals are private, and a test fails when something reaches past the API.
3. **Edges are thin.** A transport handler (HTTP, gRPC, tRPC, MCP) maps input, delegates, and maps
   output. Decisions live in a named operation behind it.
4. **The domain is in the types.** A value with rules is a type, not a bare `string` or `UUID`.
   Operations are named for the intent (`moveFolder`), not the resulting state
   (`setParentId`), because a write carrying replacement state drops what the caller didn't
   know about and cannot hold an invariant.
5. **A rule that matters is enforced by a test.** Each convention names the test that fails
   when it is broken and the ADR that explains it. A rule that exists only as prose drifts.

**Layers and seams:** follow the repo's own layering rule. Where it has none, ask before adding a
layer, port or interface that only one implementation would fill.

## Designing a module

Specify, concretely:
- **Responsibilities**: what it does, and what it explicitly does not.
- **Interface**: how it is called (REST, gRPC, events, function calls), as signatures, not prose.
- **Dependencies**: what it needs from other contexts, through their public API only.
- **Data ownership**: what it owns, versus what it references by ID.
- **Failure modes**: what happens when it or a dependency fails.

## Domain modelling

- Name **bounded contexts** first; aggregates come after.
- An **aggregate** is a consistency boundary. Keep it immutable: an operation returns the
  resulting state rather than mutating what the caller holds. Reference other aggregates by ID.
- **Identity comes from the session, never from a request field.** Services still take it as an
  explicit argument, so the input stays visible and testable.
- **Failures are named for what happened** (`ValidationFailed`), not for a transport code; each
  edge maps them to its own status.
- Keep **one word per concept** across code, UI and docs. Settle the names with the
  `domain-language-steward` skill while the design is still on paper: a name is cheapest to
  change before it reaches code, an API or a table.

For strategic and tactical DDD patterns, see `${SKILL_DIR}/references/ddd-patterns.md`.

## Reviewing a design

- [ ] Organised by context; no new generic bucket
- [ ] Each context reached only through its public API
- [ ] Edges only map and delegate
- [ ] Every new layer, port or interface justified by the repo's rule or a second implementation
- [ ] Names are domain words, and operations name intents
- [ ] Values with rules are types
- [ ] A new convention has a test that enforces it
- [ ] A hard-to-reverse decision has an ADR (`adr` skill), and no existing ADR is contradicted
      without one superseding it
