---
name: adr
description: "Creates an Architecture Decision Record documenting a significant technical decision with alternatives, tradeoffs, and consequences. Use when making or documenting architectural choices."
invocation:
  model: false
allowed-tools: [Read, Glob, Grep, Bash, Write]
argument-hint: "<decision-title>"
---

# Create ADR

**Decision:** $ARGUMENTS

## Process

### 1. Research Context

Before writing, understand the landscape:
- Read existing ADRs in `docs/adr/` to avoid duplicates and find related decisions
- Explore the codebase area affected by this decision
- Read `docs/steering/tech.md` if it exists, else `CLAUDE.md` and the build files, for stack and constraints
- If the decision introduces, renames or splits a domain term, settle it with `domain-language-steward` first, so the ADR records the term the code will use

### 2. Determine Name and Number

Follow the naming form `docs/adr/` already uses — `0001-slug.md` or `ADR-001-slug.md` — and
take the next number after the highest one there. With no ADRs yet, use `0001-slug.md` (MADR).

### 3. Write the ADR

Use the section form `docs/adr/` already uses, as with naming. With no ADRs yet, use the MADR 3.0
template at `${SKILL_DIR}/templates/adr-template.md`.

Create `docs/adr/{number}-{kebab-case-title}.md`, in the repo's naming and section form, covering:
- What problem or question motivated the decision
- What was chosen, and why
- At least 2 alternatives, with the pros and cons of each
- Consequences: what gets better, and what gets worse
- Links to any ADRs this interacts with

For the decision type, the Consequences also need:
- **Technology selection** — team expertise and operational cost, with benchmarks if any exist
- **Architectural change** — migration path, backward compatibility, monitoring and rollback
- **Standard or convention** — an example in practice, the escape hatches, how it is enforced
- **Deprecation** — the sunset timeline and a migration guide

### 4. Update Related ADRs

If this decision supersedes an existing ADR:
- Update the old ADR's status to `Superseded by {new ADR}` — its status only, never its content
- Add a cross-reference in both directions

### 5. Report

```markdown
## ADR Created

**File**: `docs/adr/{number}-{title}.md`
**Status**: Proposed
**Decision**: {one-line summary}
**Alternatives considered**: {count}
**Related ADRs**: {list or "none"}
```

## Key Principles

- Focus on the **why**, not implementation details
- Always document what was **not** chosen and why
- Keep it concise — an ADR should be readable in 2 minutes
- A decision without alternatives considered is not an ADR, it's an announcement
- One decision per ADR; split independent choices
- Write for a reader without today's context: name versions and configurations, explain jargon
- Be honest about downsides — consequences need real drawbacks, not just benefits
- Make consequences concrete: "p99 latency rises ~20ms", not "might affect performance"
