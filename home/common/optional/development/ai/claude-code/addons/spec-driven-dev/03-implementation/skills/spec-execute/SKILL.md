---
name: spec-execute
description: "Executes tasks from a spec using wave-based parallel execution, worktree isolation, and auto-continue. Syncs tasks.md with Claude Code's task system for dependency tracking and validation hooks."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent, EnterWorktree, ExitWorktree, TaskCreate, TaskUpdate, TaskGet, TaskList, AskUserQuestion]
argument-hint: "<feature-name> [task-number] [--no-worktree]"
---

# Execute Spec Task

**Arguments:** $ARGUMENTS

Parse arguments to extract `feature-name`, optional `task-number`, and optional `--no-worktree` flag.

## Step 1: Load Context

Read these files (skip any that don't exist):
- `.claude/steering/product.md`
- `.claude/steering/tech.md`
- `.claude/steering/structure.md`
- `.claude/specs/{feature-name}/requirements.md`
- `.claude/specs/{feature-name}/design.md`
- `.claude/specs/{feature-name}/tasks.md`

If `.claude/specs/{feature-name}/` doesn't exist, list available specs and stop.

## Step 2: Ensure Feature Branch

Check the current branch:
- If already on `feature/{feature-name}`, proceed
- If `feature/{feature-name}` exists but we're not on it, switch to it: `git checkout feature/{feature-name}`
- If it doesn't exist, create it: `git checkout -b feature/{feature-name}`

## Step 3: Sync Tasks

Parse `tasks.md` and sync with Claude Code's native task system:

1. Call `TaskList` to see what's already registered
2. For each task in `tasks.md` that doesn't have a corresponding Task tool entry:
   - `TaskCreate` with:
     - `subject`: "Task {N}: {title}"
     - `description`: The full task body (files, acceptance criteria)
     - `metadata`: `{"spec": "{feature-name}", "taskNumber": {N}, "specFile": ".claude/specs/{feature-name}/tasks.md"}`
   - Set up dependencies with `TaskUpdate(addBlockedBy: [...])` matching the "Depends on" field
3. For tasks already marked `[x]` in `tasks.md`, ensure their Task tool status is `completed`

This only needs to run once per feature — subsequent calls detect existing tasks via `TaskList`.

## Step 4: Compute Wave

If a specific task number was given, use **single-task mode** (skip to Step 5a).

Otherwise, call `TaskList` and find all tasks where:
- Status is `pending`
- All `blockedBy` tasks are `completed` (or no blockedBy)

These form the current **wave**.

- If no pending tasks remain, report "All tasks complete" and suggest creating a PR
- If all pending tasks are blocked, report which dependencies must complete first and stop

## Step 5: Create Worktrees

### 5a: Single-task mode

When a specific task number was given, only 1 task is in the wave, or `--no-worktree` was passed:

1. Mark the task `in_progress` via `TaskUpdate`
2. Unless `--no-worktree`: `EnterWorktree` with name `{feature-name}-task-{N}`
3. **Important**: `EnterWorktree` branches from `origin/HEAD` (the remote default), not the current branch. After entering, reset to the feature branch: `git reset --hard feature/{feature-name}`
4. Proceed to Step 6a (single-task execute)

### 5b: Wave mode (2+ tasks)

For each task N in the wave:
1. Mark all wave tasks `in_progress` via `TaskUpdate`
2. Create worktrees via Bash:
   ```bash
   git worktree add .claude/worktrees/{feature-name}-task-{N} -b worktree-{feature-name}-task-{N} feature/{feature-name}
   ```
3. Record the absolute path for each worktree
4. Proceed to Step 6b (wave execute)

## Step 6: Execute

### 6a: Single-task execute

Launch a `spec-task-executor` agent (foreground):
- Provide all loaded context
- Specify the exact task to execute
- Include the current working directory

Wait for completion. Proceed to Step 7a.

### 6b: Wave execute

Launch one `spec-task-executor` agent per task, **all in the same message** (parallel execution):
- Each agent prompt includes:
  - All loaded context (requirements, design, tasks)
  - The specific task to execute
  - The absolute worktree path as working directory
  - Instruction: "Your working directory is `{worktree-path}`. Run all Bash commands with `-C {worktree-path}`."
  - Instruction: "**Skip tasks.md update** — the orchestrator handles checkbox updates after merge."
  - Instruction: "Dependencies are satisfied — the orchestrator verified this."

Wait for all agents to complete. Proceed to Step 7b.

## Step 7: Validate

**CRITICAL**: If the validator returns PASS, proceed immediately to Step 8. Do NOT make any code changes based on validator observations, suggestions, or non-critical findings. Post-validation changes bypass the validation gate. Include non-blocking observations in the report for the user to review.

### 7a: Single-task validate

Launch a `task-completion-validator` agent (foreground) in the same directory:
- Provide files created/modified
- Provide acceptance criteria from the task

If **PASSED**:
1. Mark the task `completed` via `TaskUpdate` (the `TaskCompleted` hook runs additional checks)
2. Update `tasks.md` checkbox: `- [ ] ### Task N` → `- [x] ### Task N`

If **FAILED**:
1. Keep the task `in_progress`
2. Report what failed

Proceed to Step 8a.

### 7b: Wave validate

Launch one `task-completion-validator` agent per task, **all in the same message** (parallel):
- Each agent runs in its task's worktree path
- Provide files created/modified and acceptance criteria

Collect results. For each task:
- If **PASSED**: mark `completed` via `TaskUpdate`
- If **FAILED**: keep `in_progress`

Proceed to Step 8b.

## Step 8: Merge

### 8a: Single-task merge

If a worktree was entered:
- If **PASSED**: `ExitWorktree`, then `git merge worktree-{feature-name}-task-{N} --no-edit`
- If **FAILED**: `ExitWorktree`, feature branch untouched. User can retry.

Proceed to Step 9.

### 8b: Wave merge (in task-number order)

Sort passing tasks by task number (ascending). For each passing task N, **in order**:

1. `git rebase feature/{feature-name} worktree-{feature-name}-task-{N}`
2. If rebase conflicts: `git rebase --abort`, mark task as merge conflict, skip it
3. `git checkout feature/{feature-name} && git merge worktree-{feature-name}-task-{N} --no-edit`

After all merges:
1. Update `tasks.md` checkboxes for all successfully merged tasks in one edit
2. Clean up all wave worktrees:
   ```bash
   git worktree remove .claude/worktrees/{feature-name}-task-{N}
   git branch -d worktree-{feature-name}-task-{N}
   ```

Proceed to Step 9.

## Step 9: Report and Continue

### Single-task report

```markdown
## Task {N}: {title}

**Status**: {Complete | Failed}
**Branch**: `worktree-{feature-name}-task-{N}` → merged to `feature/{feature-name}`
**Files**: {list}

### Validation: {PASS | FAIL}
{Details}
```

### Wave report

```markdown
## Wave Results

| Task | Title | Execute | Validate | Merge | Status |
|------|-------|---------|----------|-------|--------|
| {N}  | {t}   | PASS    | PASS     | OK    | Merged |
| {M}  | {t}   | PASS    | FAIL     | --    | Failed |

**Merged**: {list} → `feature/{feature-name}`
**Failed**: {list} (retry with `/spec-execute {feature} {N}`)
```

### Auto-Continue

After reporting, check `TaskList` for more pending/unblocked tasks:
- If tasks remain: use `AskUserQuestion` — "Wave complete. Continue to next wave? ({count} tasks ready). Say 'keep going' to run all remaining waves."
- If **"keep going"**: proceed through remaining waves without prompting
- If **no more tasks**: "All tasks complete on `feature/{feature-name}`. Ready for PR."
