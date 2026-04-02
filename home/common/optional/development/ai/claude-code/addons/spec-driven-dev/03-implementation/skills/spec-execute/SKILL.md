---
name: spec-execute
description: "Executes tasks from a spec using worktree isolation per task. Each task gets its own branch, merged back to the feature branch on success. Auto-continues on request."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent, EnterWorktree, ExitWorktree]
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

All task work happens on the feature branch (or in worktrees branched from it).

## Step 3: Identify Task

If a task number was given, find that task. Otherwise find the **next incomplete task** — the first `- [ ] ### Task N` whose dependencies are all `[x]`.

Task-level items use the format `- [ ] ### Task N: Title`.
- If no incomplete tasks remain, report "All tasks complete" and suggest creating a PR from the feature branch
- If the identified task has unmet dependencies, report which must be completed first and stop

## Step 4: Enter Worktree (default)

Unless `--no-worktree` was passed:
1. Use `EnterWorktree` with name `{feature-name}-task-{N}`
2. This creates a worktree branched from HEAD (the feature branch), so it has all previous tasks' changes
3. Both the executor and validator will run in this worktree

If `--no-worktree` was passed, work directly on the feature branch.

## Step 5: Execute

Launch a `spec-task-executor` agent (foreground):
- Provide all loaded context
- Specify the exact task to execute
- Include the current working directory

Wait for it to complete before proceeding.

## Step 6: Validate Completion

Launch a `task-completion-validator` agent (foreground):
- Provide the list of files created/modified by the executor
- Provide the task's acceptance criteria

The validator runs in the **same directory** as the executor (worktree or feature branch), so it sees all changes.

## Step 7: Exit Worktree and Merge (if applicable)

If a worktree was entered in Step 4:
- If validator **PASSED**:
  1. `ExitWorktree` to return to the feature branch
  2. Merge the task branch: `git merge worktree-{feature-name}-task-{N} --no-edit`
  3. The feature branch now has this task's changes
- If validator **FAILED**:
  1. `ExitWorktree` to return to the feature branch
  2. Report what failed — the feature branch is untouched
  3. The user can retry the task

## Step 8: Report and Continue

```markdown
## Task {N}: {title}

**Status**: {Complete | Failed}
**Branch**: `worktree-{feature-name}-task-{N}` → merged to `feature/{feature-name}`
**Files**: {list}

### Validation: {PASS | FAIL}
{Details}
```

### Auto-Continue

After reporting, check for more incomplete tasks:
- If **yes**: "Continue to Task {N+1}? (say 'keep going' to run all remaining)"
- If **"keep going"**: proceed through remaining tasks without waiting
- If **no more tasks**: "All tasks complete on `feature/{feature-name}`. Ready for PR."
