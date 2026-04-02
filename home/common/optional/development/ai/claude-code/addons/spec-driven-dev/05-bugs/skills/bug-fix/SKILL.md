---
name: bug-fix
description: "Implement a bug fix per the bug report, add regression test, and validate."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent]
argument-hint: "<bug-slug>"
---

# Fix Bug

**Arguments:** $ARGUMENTS

Parse argument to extract the bug slug (e.g., `bug-login-timeout`).

## Step 1: Load Bug Report

Read `.claude/specs/{bug-slug}/bug-report.md`.

If it doesn't exist:
```
Error: No bug report found for "{bug-slug}".
Run `/bug-create {description}` first.
Available bug reports: {list from .claude/specs/bug-*/}
```

## Step 2: Implement Fix

For each task in the bug report's Fix Tasks section:

1. Read the files identified in the task
2. Implement the fix following the suggested approach
3. Keep changes minimal — fix the bug, don't refactor surrounding code

## Step 3: Verify Fix

1. Follow the reproduction steps from the bug report
2. Confirm the bug no longer occurs
3. Run the full test suite to check for regressions

## Step 4: Add Regression Test

Write a test that:
- Reproduces the exact conditions from the bug report
- Would have FAILED before the fix
- PASSES with the fix applied
- Is named descriptively: "should {expected behavior} when {condition that caused the bug}"

## Step 5: Validate

Launch a `task-completion-validator` agent to check the fix for shortcuts, stubs, or missing error handling.

## Step 6: Mark Complete

Edit `bug-report.md` to mark fix tasks as `[x]`.

## Step 7: Report

```markdown
## Bug Fix: {bug-slug}

**Status**: {Fixed | Partially Fixed | Could Not Fix}

### Changes
- `{file}` — {what changed}

### Regression Test
- **File**: `{test file path}`
- **Test**: `{test name}`

### Verification
- Reproduction steps: {no longer reproduces / still reproduces}
- Test suite: {pass}/{total} passing
- Validation: {PASS | FAIL}

### Notes
{Any concerns, related issues discovered, or follow-up needed}
```
