---
name: architecture-standards
description: "Architecture conventions, ADR process, design principles, and component patterns. Preloaded by agents that need architectural context."
invocation:
  user: false
---

# Architecture Standards

## Design Principles

1. **Design for failure** — assume components will fail; handle gracefully
2. **Loose coupling** — minimize dependencies between components
3. **High cohesion** — keep related functionality together
4. **Start simple** — prefer the simplest architecture that meets requirements; evolve as needed
5. **Document trade-offs** — always record what was chosen AND what was rejected and why

## Architecture Decision Records (ADRs)

Significant architectural decisions MUST be documented as ADRs using MADR 3.0 format.

**When to write an ADR:**
- New technology or framework choice
- Significant structural change (new service, module boundary change)
- Integration pattern selection (sync vs async, REST vs gRPC)
- Data storage decisions
- Security architecture choices

**Where:** `.sdd/decisions/ADR-NNN-title.md`

**Template:** Use the `adr` skill, which fills in the MADR 3.0 template for you.

**Numbering:** Sequential, never reuse. Check existing ADRs first.

**Status lifecycle:** Proposed → Accepted → Deprecated/Superseded

## Component Design

When designing components, specify:
- **Responsibilities** — what it does and doesn't do
- **Interfaces** — how it communicates (REST, gRPC, events, function calls)
- **Dependencies** — what it needs from other components
- **Data ownership** — what data it owns vs references by ID
- **Failure modes** — what happens when it or its dependencies fail

## Diagramming

- Use **Mermaid** for inline diagrams in spec documents
- Use **C4 model** levels for system-level views (Context, Container, Component)
- Sequence diagrams for key interaction flows

## Domain Modeling

When the feature involves complex domain logic:
- Identify **bounded contexts** — core domain (competitive advantage), supporting, generic
- Design **aggregates** as consistency boundaries (reference others by ID only)
- Define **domain events** for cross-context communication
- Establish **ubiquitous language** — consistent terms across code and docs

For detailed DDD patterns, see `${SKILL_DIR}/references/ddd-patterns.md`.

## Architectural Review Checklist

When reviewing designs or implementations for architectural compliance:
- [ ] Layer boundaries maintained (no cross-layer shortcuts)
- [ ] Dependencies flow in one direction (no circular deps)
- [ ] New components have clear responsibilities and interfaces
- [ ] Existing ADRs are respected (no contradictions without a new ADR)
- [ ] Cross-service contracts are defined (not assumed)
- [ ] Error handling follows the established pattern
- [ ] Scaling characteristics considered
