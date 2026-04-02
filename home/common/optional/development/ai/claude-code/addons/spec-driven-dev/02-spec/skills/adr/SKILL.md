---
name: adr
description: "Creates an Architecture Decision Record documenting a significant technical decision with alternatives, tradeoffs, and consequences. Use when making or documenting architectural choices."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash, Write]
argument-hint: "<decision-title>"
---

# Create ADR

**Decision:** $ARGUMENTS

## Process

### 1. Research Context

Before writing, understand the landscape:
- Read existing ADRs in `.claude/specs/decisions/` to avoid duplicates and find related decisions
- Explore the codebase area affected by this decision
- Read `.claude/steering/tech.md` for current stack and constraints

### 2. Determine Next Number

Find the highest existing ADR number in `.claude/specs/decisions/` and increment by 1.
If no ADRs exist, start at ADR-001.

### 3. Write the ADR

Read the template at `${CLAUDE_SKILL_DIR}/../architecture-standards/references/adr-template.md`.

Create `.claude/specs/decisions/ADR-{NNN}-{kebab-case-title}.md` filling in:
- **Context**: What problem or question motivated this decision
- **Decision**: What we chose and why
- **Options Considered**: At least 2 alternatives with pros/cons for each
- **Consequences**: Positive, negative, and neutral outcomes
- **Related Decisions**: Links to any ADRs this interacts with

### 4. Update Related ADRs

If this decision supersedes an existing ADR:
- Update the old ADR's status to `Superseded by ADR-{NNN}`
- Add a cross-reference in both directions

### 5. Report

```markdown
## ADR Created

**File**: `.claude/specs/decisions/ADR-{NNN}-{title}.md`
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
