---
name: tdd-cycle
description: "Orchestrates RED-GREEN-BLUE TDD cycle using context-isolated agents. Enforces phase gates between test writing, implementation, and refactoring."
invocation:
  model: false
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent]
argument-hint: "<feature-description>"
---

# TDD Cycle

Implement a feature using strict Test-Driven Development with three isolated phases.

## Quick Start

Briefly confirm with the user:
- What feature/behavior to implement
- Where tests should live (detect from project conventions if not specified)

Then proceed to the cycle.

## The RED-GREEN-BLUE Cycle

For each piece of functionality, execute all three phases sequentially. Never skip a phase.

### Phase 1: RED — Write Failing Tests

Launch a `tdd-test-writer` agent:
- Provide: the requirements/acceptance criteria, the target test directory, project test conventions
- The agent writes tests WITHOUT seeing any implementation

**Phase Gate**: Review the agent's output:
- Tests must exist and be runnable
- Tests must FAIL (confirming they test something not yet implemented)
- Confidence must be >= 70
- If insufficient, iterate with the agent or ask the user

### Phase 2: GREEN — Write Minimal Implementation

Launch a `tdd-implementer` agent:
- Provide: the test file paths ONLY (not the requirements — the agent reads the tests themselves)
- The agent writes MINIMAL code to pass all tests

**Phase Gate**: ALL tests must pass.
- If tests fail after the agent's session, review failures
- Either retry or consult the user

### Phase 3: BLUE — Refactor

Launch a `tdd-refactorer` agent:
- Provide: implementation file paths AND test file paths
- The agent evaluates whether refactoring is warranted and applies it

**Phase Gate**: ALL tests must still pass after refactoring.

## Multiple Features

When implementing multiple features or behaviors, complete the FULL cycle for each before starting the next:

```
Feature 1: RED → GREEN → BLUE ✓
Feature 2: RED → GREEN → BLUE ✓
Feature 3: RED → GREEN → BLUE ✓
```

Never batch RED phases across features — this defeats context isolation.

## Phase Violations

These are NEVER acceptable:
- Writing implementation before the test (skipping RED)
- Proceeding to GREEN without seeing RED fail
- Skipping BLUE evaluation entirely
- Starting a new feature before completing the current cycle
- Sharing context between the test-writer and implementer agents

## Completion Report

After all cycles complete:

```markdown
## TDD Complete

**Feature**: {description}
**Cycles**: {count}

### Cycle {N}: {feature/behavior name}

| Phase | Files | Tests | Confidence |
|-------|-------|-------|------------|
| RED | {test files} | {count} written | {score}/100 |
| GREEN | {impl files} | {pass}/{total} passing | {score}/100 |
| BLUE | {refactored files or "—"} | {pass}/{total} passing | {score}/100 |

### Summary
{Overall assessment of implementation quality}
```
