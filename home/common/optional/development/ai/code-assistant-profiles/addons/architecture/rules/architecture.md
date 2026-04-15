---
description: Architecture conventions for ADRs, bounded contexts, interfaces, and trade-off documentation.
---

Architecture conventions:
- Document significant decisions as ADRs in docs/adr/ (MADR 3.0 format)
- Use Mermaid for inline diagrams, C4 model for system-level views
- Identify bounded contexts before designing components
- Specify component interfaces (REST, gRPC, events) in YAML format
- Always document trade-offs - what was chosen AND what was rejected and why
