---
name: spec-status
description: "Display workflow phase and task completion progress for a spec."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep]
argument-hint: "[feature-name]"
---

# Spec Status

**Arguments:** $ARGUMENTS

## If No Feature Name Given

List all specs:
1. Glob for `.claude/specs/*/tasks.md`
2. For each, count completed vs total tasks
3. Display summary table

```markdown
## All Specs

| Spec | Phase | Progress | Next Task |
|------|-------|----------|-----------|
| {name} | {phase} | {done}/{total} ({pct}%) | Task {N} |
```

## If Feature Name Given

1. Check `.claude/specs/{feature-name}/` exists. If not, list available specs and stop.

2. Determine current phase:
   - Only `requirements.md` exists → **Requirements**
   - `requirements.md` + `design.md` → **Design**
   - All three docs exist, no tasks started → **Ready**
   - Some tasks `[x]` → **Execution**
   - All tasks `[x]` → **Complete**

3. Parse `tasks.md` for task details:
   - Total tasks, completed count, remaining count
   - Dependencies for each task
   - Next available task (first uncompleted with all deps met)

```markdown
## Spec Status: {feature-name}

**Phase**: {Requirements | Design | Ready | Execution | Complete}
**Progress**: {completed}/{total} tasks ({percentage}%)

| # | Task | Status | Depends On |
|---|------|--------|------------|
| 1 | {title} | {done/pending/blocked} | {deps or "—"} |
| 2 | {title} | {done/pending/blocked} | {deps or "—"} |

**Next task**: Task {N} — {title}
**Run**: `/spec-execute {feature-name} {N}`
```
