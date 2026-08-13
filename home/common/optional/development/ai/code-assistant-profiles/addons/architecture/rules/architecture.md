---
description: What goes in an ADR, plus diagram and component-boundary conventions.
---

Writing an ADR: record the trade-off, not just the outcome — what was chosen and what was rejected, each with the reason. A decision without its rejected alternatives is unreviewable later. Existing ADRs stand until superseded: if a new decision contradicts one, say so explicitly and write a new ADR overriding it rather than editing the old one. Where ADRs live and how they are numbered is the `design-notes` rule's business.

Identify bounded contexts before designing components, and specify component interfaces (REST, gRPC, events) concretely rather than describing them in prose. Use Mermaid for inline diagrams and the C4 model for system-level views.
