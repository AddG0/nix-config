---
name: spec-execute
description: "Executes a specific task from a spec in an isolated worktree, merges changes back, then validates completion. Use when ready to implement a spec task."
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent]
argument-hint: "<feature-name> <task-number>"
---

# Execute Spec Task

**Arguments:** $ARGUMENTS

Parse arguments to extract `feature-name` and `task-number`.

## Step 1: Load Context

Read these files (skip any that don't exist):
- `.claude/steering/product.md`
- `.claude/steering/tech.md`
- `.claude/steering/structure.md`
- `.claude/specs/{feature-name}/requirements.md`
- `.claude/specs/{feature-name}/design.md`
- `.claude/specs/{feature-name}/tasks.md`

If `.claude/specs/{feature-name}/` doesn't exist, list available specs and stop:
```
Error: No spec found for "{feature-name}".
Available specs: {list from .claude/specs/}
```

## Step 2: Validate Task

Parse `tasks.md` to find Task {task-number}. Task-level items use the format `- [ ] ### Task N: Title`.
- If the task doesn't exist, list available tasks and stop
- If the task is already `[x]`, report it's complete and suggest the next incomplete task
- If dependency tasks are not `[x]`, report which must be completed first and stop

## Step 3: Execute

Launch a `spec-task-executor` agent:
- Provide all loaded context
- Specify the exact task to execute
- Include the project root path

The executor runs in an **isolated worktree** (`isolation: worktree`). It commits all changes (code + tasks.md update) in the worktree branch.

## Step 4: Merge Worktree Changes

After the executor completes, merge its worktree branch back into the current branch:

1. The agent result includes the worktree branch name
2. Merge the branch: `git merge <worktree-branch> --no-edit`
3. If merge conflicts occur on `tasks.md`, accept the worktree version (it has the updated checkbox)
4. Verify `tasks.md` shows the task as `[x]`

If the executor failed or produced no changes, skip the merge.

## Step 5: Validate Completion

After merging, launch a `task-completion-validator` agent:
- Provide the list of files created/modified
- Provide the task's acceptance criteria

## Step 6: Report

```markdown
## Task Execution: {feature-name} / Task {number}

**Task**: {title}
**Status**: {Complete | Failed | Blocked}
**Files Modified**: {list}

### Execution
{Summary of what was implemented}

### Validation
**Verdict**: {PASS | FAIL}
{Violation details if FAIL}

### Next Task
{Next incomplete task, or "All tasks complete — run spec-reviewer to verify the full feature"}
```
