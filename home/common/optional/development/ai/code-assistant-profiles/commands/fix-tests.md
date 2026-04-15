---
description: Run tests in a loop, fix test issues automatically, stop on real bugs
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
argument-hint: "[test-pattern] [--max-iterations=10]"
---

# Fix Tests Command

Run tests in a loop, automatically fixing test-related issues. **Stop and report when a real bug is found.**

**Arguments:** "$ARGUMENTS"

## Key Distinction

| Type | Action | Examples |
|------|--------|----------|
| **Test Issue** | Fix automatically, continue loop | Outdated mock, wrong assertion, missing stub, async timing |
| **Real Bug** | **STOP** and report to user | Logic error, null pointer, missing validation, broken business logic |

## Process

### Step 1: Setup

Detect test framework and package manager:

```bash
# Detect JS/TS package manager (priority: pnpm > yarn > npm)
ls pnpm-lock.yaml yarn.lock package-lock.json 2>/dev/null | head -1

# Check package.json for test script
cat package.json 2>/dev/null | grep -A5 '"scripts"' | grep test || true
```

**Package manager detection:**
- `pnpm-lock.yaml` exists -> use `pnpm`
- `yarn.lock` exists -> use `yarn`
- `package-lock.json` exists -> use `npm`
- None exist -> default to `pnpm`

Set `MAX_ITERATIONS` to 10 (or user-provided value).
