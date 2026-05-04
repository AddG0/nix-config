---
name: bug-create
description: "Create a structured bug report with reproduction steps, root cause analysis, and fix tasks."
invocation:
  model: false
allowed-tools: [Read, Glob, Grep, Bash, Write]
context: fork
argument-hint: "<short-description>"
---

# Create Bug Report

**Arguments:** $ARGUMENTS

A bug report template is available at `${SKILL_DIR}/templates/bug-report.md.template`.

## Step 1: Gather Information

Extract the bug description from arguments. Ask the user for any missing details:
- What is the observed behavior?
- What was expected?
- How to reproduce? (steps, input, environment)

## Step 2: Investigate

- Search the codebase for relevant code paths
- Check recent git history for related changes
- Look for related tests and whether they cover this scenario
- Identify the likely root cause

## Step 3: Write Bug Report

Create a slug from the description (kebab-case, max 40 chars).
Read the template at `${SKILL_DIR}/templates/bug-report.md.template`, fill it in, and write to `.sdd/specs/bug-{slug}/bug-report.md`.

## Step 4: Report

```markdown
## Bug Report Created

**Location**: `.sdd/specs/bug-{slug}/bug-report.md`
**Root Cause**: `{file}:{line}` — {brief cause}
**Confidence**: {score}/100
**Fix Tasks**: {count}

**Next step**: Run `/bug-fix bug-{slug}` to implement the fix.
```
