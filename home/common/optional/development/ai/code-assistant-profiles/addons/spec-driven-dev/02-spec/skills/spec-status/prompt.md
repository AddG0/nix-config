---
name: spec-status
description: "Display workflow phase and task completion progress for a spec."
invocation:
  model: false
allowed-tools: [Read, Glob, Grep]
argument-hint: "[feature-name]"
---

# Spec Status

Report progress for spec `$1`. If `$1` is empty, report on every spec under `.sdd/specs/`.

## When `$1` is empty — list all specs

1. Glob `.sdd/specs/*/tasks.md`.
2. For each, count completed (`[x]`) vs total tasks.
3. Print:

   ```markdown
   ## All Specs

   | Spec | Phase | Progress | Next Task |
   |------|-------|----------|-----------|
   | {name} | {phase} | {done}/{total} ({pct}%) | Task {N} |
   ```

## When `$1` names a spec

1. Verify `.sdd/specs/$1/` exists. If not, list available specs and stop.

2. Determine phase:
   - only `requirements.md` → **Requirements**
   - + `design.md` → **Design**
   - all three docs, no tasks started → **Ready**
   - some tasks `[x]` → **Execution**
   - all tasks `[x]` → **Complete**

3. Parse `tasks.md`:
   - total / completed / remaining counts
   - dependencies per task
   - next available task (first uncompleted with all deps met)

4. Print:

   ```markdown
   ## Spec Status: $1

   **Phase**: {Requirements | Design | Ready | Execution | Complete}
   **Progress**: {completed}/{total} tasks ({percentage}%)

   | # | Task | Status | Depends On |
   |---|------|--------|------------|
   | 1 | {title} | {done/pending/blocked} | {deps or "—"} |
   | 2 | {title} | {done/pending/blocked} | {deps or "—"} |

   **Next task**: Task {N} — {title}
   **Run**: `/spec-execute $1 {N}`
   ```
