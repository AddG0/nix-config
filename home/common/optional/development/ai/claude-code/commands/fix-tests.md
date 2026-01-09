---
description: Run tests in a loop, fix test issues automatically, stop on real bugs
allowed-tools: ["Bash", "Read", "Glob", "Grep", "Edit", "Write"]
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
- `pnpm-lock.yaml` exists → use `pnpm`
- `yarn.lock` exists → use `yarn`
- `package-lock.json` exists → use `npm`
- None exist → default to `pnpm`

Set `MAX_ITERATIONS` to 10 (or user-provided value).

---

## Step 2: Main Loop

```
iteration = 0
while iteration < MAX_ITERATIONS:
    iteration++

    1. Run tests
    2. If all pass → SUCCESS, exit loop
    3. Parse failures
    4. For each failure:
       - Analyze root cause
       - If REAL BUG → STOP, report to user
       - If TEST ISSUE → fix it
    5. Continue to next iteration
```

### 2a. Run Tests

```bash
pnpm test 2>&1
```

If user provided a pattern:
```bash
pnpm test <pattern> 2>&1
```

### 2b. Check Results

- **All tests pass** → Exit loop, report success
- **Tests fail** → Continue to analysis

### 2c. Parse Each Failure

For each failing test, extract:
- Test name and file location
- Error message and stack trace
- Expected vs actual values

### 2d. Classify Each Failure

**This is critical.** For each failure, determine if it's a test issue or real bug:

#### TEST ISSUE (fix automatically):

- **Outdated assertion** - Test expects old behavior, code intentionally changed
- **Missing/wrong mock** - External dependency not properly mocked
- **Async timing** - Race condition in test, not production code
- **Snapshot outdated** - UI changed intentionally, snapshot needs update
- **Test environment** - Missing setup, wrong config for test
- **Flaky test** - Passes sometimes, test logic issue

#### REAL BUG (stop and report):

- **Logic error** - Code does wrong thing (e.g., `>` instead of `>=`)
- **Null/undefined crash** - Missing null check in source code
- **Missing validation** - Input not validated, causes downstream error
- **Broken business logic** - Calculation wrong, workflow broken
- **Type error** - Wrong types causing runtime failure
- **Integration failure** - Components don't work together correctly
- **Security issue** - Auth bypass, injection vulnerability

### 2e. Take Action

**If TEST ISSUE:**
1. Read the test file
2. Apply the fix (update mock, fix assertion, add async handling)
3. Log what was fixed
4. Continue loop

**If REAL BUG:**
1. **STOP immediately**
2. Report to user with full details (see Step 3)

---

## Step 3: Bug Report (when real bug found)

When a real bug is detected, stop and report:

```markdown
## 🛑 Real Bug Detected - Stopping

**Test**: `<test name>`
**File**: `<test file>:<line>`

### What Failed
<error message and assertion>

### Root Cause Analysis
<explanation of why this is a real bug, not a test issue>

### Bug Location
**File**: `<source file>:<line>`
**Code**:
```<language>
<relevant code snippet>
```

### Impact
<what this bug would cause in production>

### Suggested Fix
<your recommendation>

---

**Iteration**: <N>/<MAX>
**Tests Fixed This Run**: <count>
**Action Required**: Please review and fix this bug, then run `/fix-tests` again.
```

---

## Step 4: Success Report (when all tests pass)

```markdown
## ✅ All Tests Passing

**Iterations**: <N>
**Tests Fixed**: <count>

### Fixes Applied

| Test | Issue Type | Fix |
|------|------------|-----|
| `test_name` | Outdated mock | Updated return value |
| `test_name_2` | Async timing | Added `waitFor` wrapper |

### Files Modified
- `tests/auth.test.ts` - Updated mocks
- `tests/utils.test.ts` - Fixed async handling
```

---

## Step 5: Max Iterations Report (if limit reached)

```markdown
## ⚠️ Max Iterations Reached

**Iterations**: <MAX>/<MAX>
**Tests Still Failing**: <count>

### Remaining Failures

| Test | Issue | Why Not Fixed |
|------|-------|---------------|
| `test_name` | <description> | <reason - might be real bug, needs review> |

### Recommendation
Review remaining failures manually - they may be real bugs or complex test issues.
```

---

## Classification Examples

### Example: TEST ISSUE (fix it)

```
FAIL src/api.test.ts
  ✕ should return user data
    Expected: { name: "John", email: "john@example.com" }
    Received: { name: "John", email: "john@example.com", createdAt: "2024-01-01" }
```
**Analysis**: API now returns `createdAt` field. This is an intentional change.
**Action**: Update test assertion to include new field. **Continue loop.**

### Example: REAL BUG (stop)

```
FAIL src/checkout.test.ts
  ✕ should calculate total with discount
    Expected: 90
    Received: 100
```
**Analysis**: Discount calculation is wrong in source code. `applyDiscount()` not being called.
**Action**: **STOP.** Report bug to user. This is broken business logic.

### Example: TEST ISSUE (fix it)

```
FAIL src/auth.test.ts
  ✕ should reject invalid token
    TypeError: Cannot read property 'verify' of undefined
```
**Analysis**: `jwt` module not mocked in test setup.
**Action**: Add mock for jwt module. **Continue loop.**

### Example: REAL BUG (stop)

```
FAIL src/user.test.ts
  ✕ should not allow duplicate emails
    Expected: throws "Email already exists"
    Received: { id: 2, email: "dupe@test.com" }
```
**Analysis**: Uniqueness validation missing in `createUser()`. Users can register with duplicate emails.
**Action**: **STOP.** Report bug - this is a missing validation that would cause production issues.

---

## Notes

- **Bias toward stopping**: When uncertain, classify as REAL BUG and stop
- **Read source code**: Always read the source file being tested before classifying
- **Check git history**: Recent changes help determine if test is outdated vs code is broken
- **Trust the test intent**: If a test checks important business logic, assume the test is right
