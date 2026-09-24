---
name: interview
description: "Researches the codebase, then interviews the user to turn a new feature idea into a requirements summary. Use when requirements for new work are unclear."
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
   - `docs/steering/` project context, ADRs under `docs/adr/`, and any current work folder
   - `README.md`, `CLAUDE.md`
   - Recent git history in the affected area: `git log --oneline -20 -- {relevant paths}`

3. **Build a mental model** of:
   - What already exists that this feature could reuse or extend
   - What technical constraints the codebase imposes
   - What patterns the implementation should follow
   - What integration points exist

**Present a brief summary of what you found** before starting questions. This shows the user you've done your homework and lets them correct any misunderstandings early.

## Phase 1: Interview

Call the Skill tool with `grilling`, and run the interview through it.

Seed the design tree with these branches, dropping any that research or the user's opening message already settled:

- **Problem**: what it solves, for whom, why now
- **Success criteria**: how you'll know it works
- **Scope**: what is explicitly out, what waits for v2
- **Priorities**: which of two named goals wins when they conflict
- **Business rules and edge cases** not visible in the code
- **User experience** expectations
- **Security**: who must not have access, compliance constraints
- **External dependencies**: third-party services, APIs, other teams
- **Tradeoffs**: what to cut to ship sooner, how it may change in 6 months, where to be extra careful

Never put a question to the user that the Phase 0 research answers — tech stack, layout, existing patterns, schemas. If the user says "I don't know" or "you pick", record it as an open question and move on.

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
{Extracted from research and the interview, using EARS format where applicable}

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
{From the tradeoffs branch}

## Open Questions
{Anything unresolved}
```

Offer to save this summary as `docs/work/{topic}/interview.md`, or alongside an existing work folder if the repo already has one. It is a durable artifact worth keeping, and later work reads it. Do not build a further set of documents from it unless asked.

## Rules

- Research first, ask second — never ask what you can find yourself
- Present your research summary before the first round
- Always end with the synthesized summary
