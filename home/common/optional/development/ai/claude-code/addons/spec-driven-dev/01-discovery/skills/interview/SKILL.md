---
name: interview
description: "Explores the codebase autonomously, then interviews the user about decisions only humans can make. Produces a structured spec covering problem, scope, tradeoffs, and edge cases."
argument-hint: "[topic or feature name]"
---

# Feature Interview

Research first, then ask only what you can't find yourself.

## Phase 0: Autonomous Research (before asking any questions)

Before asking the user a single question, gather as much context as you can:

1. **Explore the codebase** — Use Glob, Grep, and Read to understand:
   - Project structure (directory layout, key entry points)
   - Tech stack (languages, frameworks, test runners, build tools — from config files)
   - Existing patterns in the area the feature will touch
   - Related code, prior art, similar features already implemented
   - Database schemas, API routes, service boundaries
   - Test patterns and conventions

2. **Read project context** if it exists:
   - `.claude/steering/product.md`, `tech.md`, `structure.md`
   - `README.md`, `CLAUDE.md`
   - Recent git history in the affected area: `git log --oneline -20 -- {relevant paths}`

3. **Build a mental model** of:
   - What already exists that this feature could reuse or extend
   - What technical constraints the codebase imposes
   - What patterns the implementation should follow
   - What integration points exist

**Present a brief summary of what you found** before starting questions. This shows the user you've done your homework and lets them correct any misunderstandings early.

## Phase 1: Human-Only Questions (3-5 questions)

Now ask ONLY questions that require human judgment — things you cannot determine from the code:

1. **The problem**: What are you trying to solve? For whom? Why now?
2. **Success criteria**: How will you know this works? What's the business outcome?
3. **Scope**: What is explicitly NOT part of this? What can wait for v2?
4. **Priorities**: If you had to choose between {X} and {Y}, which matters more?

**Do NOT ask about:**
- Tech stack, test framework, build commands (you already know)
- Directory structure, file naming conventions (you already know)
- Existing patterns, schemas, API routes (you already know)
- How existing features work (you already know)

One question at a time. Wait for each answer. Skip questions the user already addressed in their initial description.

## Phase 2: Targeted Depth (2-4 questions)

Based on Phase 0 research + Phase 1 answers, ask about gaps only a human can fill:

1. **Business rules**: Are there domain-specific rules or edge cases that aren't in the code?
2. **User expectations**: What should the user experience be? Any UX requirements?
3. **Security/authorization**: Who should NOT have access? Any compliance requirements?
4. **External dependencies**: Are there third-party services, APIs, or teams involved?

Skip anything you can infer from the codebase.

## Phase 3: Tradeoffs (1-3 questions)

1. **MVP scope**: What could be cut to ship faster?
2. **Evolution**: How might this need to change in 6 months?
3. **Risk tolerance**: Any areas where we should be extra careful vs. move fast?

## Adaptive Behavior

- If the user gives comprehensive answers, skip redundant questions
- If the user says "I don't know" or "whatever you think", note it as an open question and move on
- If security or data concerns emerge, dig deeper
- Total questions across all phases should typically be **5-10**, not 15+
- End the interview when coverage is sufficient

## Output

Synthesize everything (your research + user answers) into a structured document:

```markdown
# {Feature Name} — Interview Summary

## Problem
{What this solves and for whom}

## Users & Actors
{Who uses this and how}

## Codebase Context
{What you found during autonomous research — existing patterns, related code, integration points, tech constraints}

## Requirements
{Extracted from all phases, using EARS format where applicable}

### Must Have
1. {requirement}

### Should Have
1. {requirement}

### Won't Have (v1)
1. {explicit non-goal}

## Technical Approach (preliminary)
{Based on codebase research — existing patterns to follow, components to extend, suggested architecture}

## Edge Cases & Error Handling
{From research + user input}

## Security Considerations
{From research + user input}

## Tradeoffs & Decisions
{From Phase 3}

## Open Questions
{Anything unresolved}

## Recommended Next Step
Run `/spec-create {feature-name}` to formalize this into a full specification with validation.
```

## Rules

- Research FIRST, ask SECOND — never ask what you can find yourself
- One question at a time — wait for the answer
- Maximum 10 questions total across all phases
- Present your research summary before the first question
- Never ask about implementation details you can read from the code
- Always end with the synthesized summary
