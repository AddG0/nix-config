---
name: spec-create
description: "Create a complete specification through Requirements → Design → Tasks with validation gates at each stage. Creates .claude/specs/{feature}/ directory."
argument-hint: "<feature-name> [description]"
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit, Agent]
---

# Spec Creation

Create a complete specification for a feature through a structured pipeline with validation at each stage.

Templates for each document are in `${CLAUDE_SKILL_DIR}/templates/`. Read them to use as the starting structure.

**Template flexibility**: Templates are starting points, not rigid forms. Omit sections that are not relevant to this feature (e.g., skip "API / Interface Changes" for a CLI tool, skip "State Management" for a stateless utility). Do not leave sections as empty headers — either fill them or remove them.

## Setup

1. Parse the feature name from arguments (kebab-case)
2. Create `.claude/specs/{feature-name}/` directory
3. If steering files exist (`.claude/steering/`), read them for project context
4. If no steering files exist, note that `/spec-steering-setup` can create them

## Phase 1: Requirements

### Gather Information

If the user provided a description, use it. If thin, ask 3-5 targeted questions:
- Who is the user/actor?
- What problem does this solve?
- What are the boundaries (explicitly NOT in scope)?
- Are there existing patterns in the codebase to follow?
- What are the acceptance criteria?

### Write `.claude/specs/{feature-name}/requirements.md`

Read the template at `${CLAUDE_SKILL_DIR}/templates/requirements.md.template` and fill it in.

EARS format types for acceptance criteria:
- **Ubiquitous**: The system shall {requirement}
- **Event-driven**: When {trigger}, the system shall {response}
- **State-driven**: While {state}, the system shall {behavior}
- **Optional**: Where {feature is enabled}, the system shall {behavior}
- **Unwanted**: If {error condition}, the system shall {recovery}

### Validation Gate 1

Launch `spec-requirements-validator` agent to review the document.

- **PASS**: Present to user for approval. Wait for explicit approval before Phase 2.
- **NEEDS_IMPROVEMENT**: Show issues to user, ask whether to fix now or proceed.
- **MAJOR_ISSUES**: Present issues, revise, re-validate before proceeding.

**CRITICAL**: Do not proceed to Phase 2 without user approval.

## Phase 2: Design

### Architectural Design

Launch the `system-architect` agent to design the technical approach:
- Provide the approved requirements document
- The architect explores the codebase, identifies component boundaries, data flow, and integration points
- If a significant architectural decision is involved, the architect creates an ADR at `.claude/specs/decisions/ADR-NNN-title.md`

### Write `.claude/specs/{feature-name}/design.md`

Read the template at `${CLAUDE_SKILL_DIR}/templates/design.md.template` and incorporate the architect's output:
- Component boundaries and responsibilities
- Data models and interfaces
- Integration points and cross-service impact
- Reference any ADRs created: "See ADR-NNN for rationale"

### Validation Gate 2

Launch `spec-design-validator` with both `requirements.md` and `design.md`.
Same gate logic as Phase 1. The validator has `architecture-standards` preloaded and checks for architectural compliance.

## Phase 3: Tasks

### Write `.claude/specs/{feature-name}/tasks.md`

Read the template at `${CLAUDE_SKILL_DIR}/templates/tasks.md.template` and fill it in.

**Important**: Each task MUST have a top-level checkbox in the format `- [ ] ### Task N: Title`. This is what the hooks and executor use to track progress. Acceptance criteria are indented sub-items without checkboxes.

Task atomicity rules:
- At most 3-5 files per task
- Single testable outcome
- No implicit decisions
- Clear file paths
- Independent verification

### Validation Gate 3

Launch `spec-task-validator` with all three documents.
Same gate logic.

## Create Feature Branch

After all three documents are written and validated, create a feature branch for implementation:

```bash
git checkout -b feature/{feature-name}
```

This branch will be the base for all task worktrees. Each `/spec-execute` task branches from it, merges back into it, and the final result is a single feature branch ready for PR.

If a branch `feature/{feature-name}` already exists (e.g., resuming work), switch to it instead of creating a new one.

## Completion

```markdown
## Spec Created: {feature-name}

**Location**: `.claude/specs/{feature-name}/`
**Branch**: `feature/{feature-name}`
**Documents**: requirements.md, design.md, tasks.md
**Tasks**: {count} tasks ready for execution
**Validation**: All gates passed

**Next step**: Run `/spec-execute {feature-name}` to begin implementation.
```
