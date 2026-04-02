---
name: spec-execute
description: "Executes tasks from a spec using native task management, worktree isolation, and auto-continue. Syncs tasks.md with Claude Code's task system for dependency tracking and validation hooks."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent, EnterWorktree, ExitWorktree, TaskCreate, TaskUpdate, TaskGet, TaskList]
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

## Step 4: Identify Next Task

If a task number was given, find that task. Otherwise find the **next unblocked pending task** from `TaskList`.

- If no pending tasks remain, report "All tasks complete" and suggest creating a PR
- If the identified task is blocked, report which dependencies must complete first and stop

Mark the task `in_progress` via `TaskUpdate`.

## Step 5: Enter Worktree (default)

Unless `--no-worktree` was passed:
1. `EnterWorktree` with name `{feature-name}-task-{N}`
2. Branches from HEAD (the feature branch), so it has all previous tasks' changes
3. Both executor and validator run in this worktree

## Step 6: Execute

Launch a `spec-task-executor` agent (foreground):
- Provide all loaded context
- Specify the exact task to execute
- Include the current working directory

Wait for completion.

## Step 7: Validate and Complete

Launch a `task-completion-validator` agent (foreground) in the same directory:
- Provide files created/modified
- Provide acceptance criteria from the task

If validator **PASSED**:
1. Mark the task `completed` via `TaskUpdate` (the `TaskCompleted` hook runs additional checks)
2. Update `tasks.md` checkbox: `- [ ] ### Task N` → `- [x] ### Task N`

If validator **FAILED**:
1. Keep the task `in_progress`
2. Report what failed

## Step 8: Exit Worktree and Merge (if applicable)

If a worktree was entered:
- If **PASSED**: `ExitWorktree`, then `git merge worktree-{feature-name}-task-{N} --no-edit`
- If **FAILED**: `ExitWorktree`, feature branch untouched. User can retry.

## Step 9: Report and Continue

```markdown
## Task {N}: {title}

**Status**: {Complete | Failed}
**Branch**: `worktree-{feature-name}-task-{N}` → merged to `feature/{feature-name}`
**Files**: {list}

### Validation: {PASS | FAIL}
{Details}
```

### Auto-Continue

After reporting, check `TaskList` for more pending/unblocked tasks:
- If **yes**: "Continue to Task {N+1}? (say 'keep going' to run all remaining)"
- If **"keep going"**: proceed through remaining tasks without waiting
- If **no more tasks**: "All tasks complete on `feature/{feature-name}`. Ready for PR."
