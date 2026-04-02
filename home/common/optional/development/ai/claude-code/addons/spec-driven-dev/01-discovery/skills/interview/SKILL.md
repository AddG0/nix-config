---
name: interview
description: "Interviews the user about a feature to produce a structured spec. Covers technical implementation, edge cases, security, and tradeoffs."
argument-hint: "[topic or feature name]"
---

# Feature Interview

Conduct a structured interview with the user to produce a feature specification.

## When to Trigger

Activate when the user asks to: "interview me about", "help me think through", "let's discuss", "brainstorm", or when a feature request is too vague to spec directly.

## Interview Process

### Round 1: Core Understanding (3-5 questions)

Ask one question at a time. Wait for each answer before the next.

Focus on:
1. **The problem**: What are you trying to solve? For whom?
2. **Success criteria**: How will you know this works correctly?
3. **Scope**: What is explicitly NOT part of this?
4. **Existing context**: Is there existing code, prior art, or constraints to know about?

Adapt based on answers — skip questions the user already addressed.

### Round 2: Technical Depth (3-5 questions)

Based on Round 1, ask about:
1. **Data**: What data does this create, read, update, or delete? What's the schema?
2. **Integration**: What existing systems or components does this touch?
3. **State**: What states can this be in? What transitions are valid?
4. **API surface**: What does the public interface look like?

Skip questions that aren't relevant to the specific feature.

### Round 3: Edge Cases and Risks (3-5 questions)

1. **Failure modes**: What happens when things go wrong? (network failure, invalid input, concurrent access, partial failure)
2. **Security**: Who should NOT be able to do this? What data is sensitive? What needs authorization?
3. **Scale**: Expected load? Data volume? Latency requirements?
4. **Migration**: Is there existing data or behavior to migrate from?

### Round 4: Tradeoffs (2-3 questions)

1. **Priorities**: If you had to choose between {X} and {Y}, which matters more?
2. **MVP scope**: What could be cut from v1 to ship faster?
3. **Evolution**: How might this need to change in the future?

## Adaptive Behavior

- If the user gives comprehensive answers, skip redundant questions
- If the user says "I don't know" or "whatever you think", note it as an open question rather than pressing
- If security or data concerns emerge, dig deeper — don't let those be vague
- Track coverage mentally: Problem, Users, Data, Integration, Errors, Security, Scale, Tradeoffs
- End the interview when all relevant areas are covered

## Output

After the interview, synthesize into a structured document:

```markdown
# {Feature Name} — Interview Summary

## Problem
{Synthesized from Round 1}

## Users & Actors
{Who uses this and how}

## Requirements
{Extracted from all rounds, using EARS format where applicable}

### Must Have
1. {requirement}
2. {requirement}

### Should Have
1. {requirement}

### Won't Have (v1)
1. {explicit non-goal}

## Technical Notes
{Key technical decisions and constraints from Round 2}

## Edge Cases & Error Handling
{From Round 3}

## Security Considerations
{From Round 3}

## Tradeoffs & Decisions
{From Round 4}

## Open Questions
{Anything the user wasn't sure about}

## Recommended Next Step
Run `/spec-create {feature-name}` to formalize this into a full specification with validation.
```

## Rules

- One question at a time — ask directly, wait for the answer
- Maximum 5 questions per round, but often fewer is better
- Never ask questions the user already answered
- Always end with the synthesized summary
- Recommend spec-create as the next step
