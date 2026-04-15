---
name: spec-mutate
description: "Runs mutation testing on files modified by a spec task to verify tests actually catch bugs. Optional quality gate. Reports surviving mutants."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash]
argument-hint: "<feature-name> [task-number]"
---

# Mutation Testing

Verify that tests actually catch bugs by introducing deliberate mutations and checking which survive.

## When to Use

Run after a task passes the `task-completion-validator`. This is an **optional** advanced quality gate — not required for every task, but valuable for critical code paths (auth, payments, data integrity).

## Process

### Step 1: Detect Framework

Identify the project's language and available mutation testing tools:

| Language | Tool | Install Check |
|----------|------|---------------|
| TypeScript/JavaScript | Stryker | `npx stryker --version` |
| Python | mutmut | `mutmut --version` |
| Rust | cargo-mutants | `cargo mutants --version` |
| Go | go-mutesting | `go-mutesting --version` |
| Java | PIT | Check pom.xml/build.gradle for pitest |

If no mutation tool is installed, report which tool is needed and stop.

### Step 2: Identify Target Files

Parse `$ARGUMENTS` for feature name and optional task number.

- If task number given: mutate only files listed in that task
- If only feature name: mutate all files listed across completed tasks
- Read `.claude/specs/{feature}/tasks.md` for the file lists

### Step 3: Run Mutations

Execute the mutation testing tool against the target files.

### Step 4: Analyze Survivors

For each surviving mutant (mutation not caught by tests):

1. **Is it a real test gap?** → Recommend writing a test to kill it
2. **Is it an equivalent mutant?** (mutation doesn't change behavior) → Document and ignore
3. **Does it reveal a real BUG?** (the mutant is actually correct) → **Report as a bug, do not write a test for buggy behavior**

### Step 5: Report

```markdown
## Mutation Testing: {feature-name}

**Files mutated**: {count}
**Total mutants**: {count}
**Killed**: {count} ({percentage}%)
**Survived**: {count}
**Equivalent**: {count}

### Target: 80%+ mutation score

### Surviving Mutants

| # | File:Line | Mutation | Category | Action |
|---|-----------|----------|----------|--------|
| 1 | `{file}:{line}` | {what was changed} | {test gap / equivalent / real bug} | {write test / ignore / report bug} |

### Recommended Tests
{For each "test gap" survivor, describe the test that would kill it}

### Bugs Discovered
{For each "real bug" survivor, describe the bug}
```
