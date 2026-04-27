# Spec-Driven Development Addon

A structured development workflow for Claude Code that enforces specs before code, test-driven implementation, and quality validation at every stage.

## Workflow

```
/spec-steering-setup          Set up project context (one-time)
        │
        ▼
/interview <feature>           Gather requirements interactively
        │
        ▼
/spec-create <feature>         Requirements → Design → Tasks (with validation gates)
        │                      Runs in forked context to keep main session clean
        ▼
/spec-execute <feature> [N]    Execute tasks (auto-continues, validates each)
        │                      Say "keep going" to run all remaining
        ▼
/spec-status [feature]         Check progress at any point
        │
        ▼
/spec-mutate <feature> [N]     Optional: mutation testing to verify test quality
```

Bug workflow: `/bug-create <description>` → `/bug-fix <bug-slug>`

## Phases

### 00-steering — Project Context

`/spec-steering-setup` analyzes the project and creates three steering documents in `.sdd/steering/`:

| Document | Contents |
|----------|----------|
| `product.md` | What the product is, who it's for, key workflows |
| `tech.md` | Stack, build/test commands, conventions, dependencies |
| `structure.md` | Directory layout, entry points, module boundaries |

These provide persistent context for all spec work. Templates are in `00-steering/skills/spec-steering-setup/templates/`.

### 01-discovery — Interview

The `interview` skill auto-triggers when you say things like "help me think through" or "let's discuss". It conducts a 4-round structured interview:

1. **Core understanding** — problem, success criteria, scope
2. **Technical depth** — data, integration, state, API surface
3. **Edge cases & risks** — failures, security, scale
4. **Tradeoffs** — priorities, MVP scope, future evolution

Produces a synthesized summary and recommends `/spec-create` as the next step.

### 02-spec — Specification Pipeline

`/spec-create <feature>` walks through three phases with a validation gate at each:

| Phase | Document | Validator Agent | Rating |
|-------|----------|----------------|--------|
| Requirements | `requirements.md` | `spec-requirements-validator` | PASS / NEEDS_IMPROVEMENT / MAJOR_ISSUES |
| Design | `design.md` | `spec-design-validator` | Same |
| Tasks | `tasks.md` | `spec-task-validator` | Same |

Each validator is **platform-enforced read-only** (sonnet, `effort: high`, `disallowedTools: Write, Edit, Bash`) and scores on weighted criteria (0-100). Human approval is required between each phase.

Templates are flexible — irrelevant sections are omitted, not left empty.

Specs are stored in `.sdd/specs/{feature-name}/`. Templates are in `02-spec/skills/spec-create/templates/`.

`/spec-status [feature]` shows progress — phase, task completion, and the next task to execute.

### 03-implementation — TDD & Task Execution

#### TDD Cycle

`/tdd-cycle` orchestrates three **context-isolated** agents:

| Phase | Agent | Model | Constraint |
|-------|-------|-------|------------|
| RED | `tdd-test-writer` | sonnet | Writes failing tests. **Never sees implementation code.** |
| GREEN | `tdd-implementer` | sonnet | Writes minimal code to pass. **Never modifies tests.** |
| BLUE | `tdd-refactorer` | opus, `effort: high` | Refactors while keeping tests green. Can skip if code is clean. |

Context isolation is enforced by running each agent as a separate subagent — the test-writer literally cannot read implementation files.

#### Task Execution

`/spec-execute <feature> [N]` uses **wave-based parallel execution**:

1. Ensures we're on the `feature/{name}` branch (creates it if needed)
2. Syncs `tasks.md` with Claude Code's native task system (dependencies, blocking)
3. Computes the next **wave** — all unblocked tasks with no pending dependencies
4. Creates a worktree per task, launches `spec-task-executor` agents **in parallel** (one per task)
5. Validates each task via `task-completion-validator` agents **in parallel**
6. Merges passing tasks back **in task-number order** (rebase then merge for clean linear history)
7. Failed tasks don't merge — retry individually with `/spec-execute {feature} {N}`
8. Offers to **auto-continue** to the next wave ("keep going" runs all remaining waves)

**Wave execution:**
```
Wave 1: [Task 1, Task 4]       ← independent, run in parallel
Wave 2: [Task 2, Task 3]       ← unblocked after Wave 1, run in parallel
Wave 3: [Task 5]               ← depends on Task 2 + Task 3
```

**Git branch structure:**
```
main
  └── feature/my-feature                  ← created by /spec-create
        ├── worktree-my-feature-task-1     ← Wave 1, merged in order
        ├── worktree-my-feature-task-4     ← Wave 1, rebased then merged
        ├── worktree-my-feature-task-2     ← Wave 2, merged in order
        └── ...                            ← PR: feature/my-feature → main
```

**Single-task mode**: Pass a specific task number (`/spec-execute feature 3`) to run one task sequentially.
**No worktree**: Pass `--no-worktree` to work directly on the feature branch.

### 04-quality — Review & Validation

Four agents for quality assurance:

| Agent | Model | Purpose |
|-------|-------|---------|
| `task-completion-validator` | opus, `effort: max` | Zero-tolerance check for stubs, mocks in production, missing error handling, hardcoded values, missing tests. Binary PASS/FAIL. |
| `spec-reviewer` | opus, `effort: high`, `memory: project` | Reviews full implementation against spec acceptance criteria. Builds alignment matrix. Accumulates project patterns across reviews. |
| `silent-failure-hunter` | sonnet | Scans for empty catches, swallowed errors, missing error propagation. Severity-rated (Critical/High/Medium/Low). |
| `acceptance-tester` | sonnet, `effort: high` | Generates behavioral acceptance tests from EARS requirements. Tests verify WHAT (user behavior), not HOW (implementation). |

All quality agents except `acceptance-tester` are **read-only** (restricted via `tools` allowlist to Read/Glob/Grep/Bash). The acceptance tester needs Write/Edit to generate test files.

#### Mutation Testing (Optional)

`/spec-mutate <feature> [task#]` introduces deliberate code mutations and checks whether the test suite catches them. Supports Stryker (JS/TS), mutmut (Python), cargo-mutants (Rust), and PIT (Java). Target: 80%+ mutation score. Distinguishes test gaps from equivalent mutants and real bugs.

### 05-bugs — Bug Reporting & Fixing

`/bug-create <description>` runs in a **forked context** to investigate the codebase, identify root cause, and write a structured report to `.sdd/specs/bug-{slug}/bug-report.md` with fix tasks.

`/bug-fix <bug-slug>` implements the fix, adds a regression test, and validates via the completion validator.

## Hooks

Six hook scripts configured across five lifecycle events:

| Hook | Event | Behavior |
|------|-------|----------|
| `session-start.sh` | `SessionStart` | Loads steering context summary and active spec status once at session start. |
| `post-compact.sh` | `SessionStart` (matcher: `compact`) | Re-injects active spec context after auto-compaction. Prevents spec drift in long sessions. |
| `spec-awareness.sh` | `UserPromptSubmit` | Injects active spec status into every prompt. Suggests `/spec-create` when feature implementation is requested without a spec. 10s timeout. |
| `protect-specs.sh` | `PreToolUse` (Edit/Write) | Protects steering docs (always) and spec requirements/design (only once implementation has started — at least one task `[x]`). Advisory `"ask"`, not blocking. |
| `spec-changelog.sh` | `PostToolUse` (Edit/Write) | Tracks changes to spec documents by appending timestamped entries to `changelog.md`. Async. |
| `task-completed.sh` | `TaskCompleted` | **Blocks** task completion if build fails, tests fail, or TODO/FIXME markers remain. Surfaces build/test output in error messages. |

### Task System Integration

`/spec-execute` syncs `tasks.md` with Claude Code's native task system:
- Each task becomes a `TaskCreate` entry with dependencies (`addBlockedBy`)
- Spinner UI shows task progress in the terminal (Ctrl+T to toggle)
- Blocked tasks cannot be started (native dependency enforcement)
- `TaskCompleted` hook runs build/test validation — completion is **blocked** if checks fail
- `tasks.md` checkboxes updated in sync for human-readable record
- Dual validation: `task-completion-validator` agent checks code quality, `task-completed` hook checks build/tests

## Auto-Triggering

| Skill | Triggers On | User-Only |
|-------|------------|-----------|
| `interview` | "help me think through", "brainstorm", "let's discuss" | No — Claude suggests it |
| `spec-create` | "spec out", "plan", "design", "write a spec" | No — Claude suggests it |
| `spec-steering-setup` | — | Yes |
| `spec-status` | — | Yes |
| `tdd-cycle` | — | Yes |
| `spec-execute` | — | Yes |
| `adr` | — | Yes |
| `spec-mutate` | — | Yes |
| `bug-create` | — | Yes (runs in fork) |
| `bug-fix` | — | Yes |

## Agent Configuration

Only 2 agents use Opus (deep cross-file reasoning). All others use Sonnet for cost efficiency.

| Agent | Model | Effort | maxTurns | Special |
|-------|-------|--------|----------|---------|
| `system-architect` | **opus** | high | 25 | `memory: project`, `skills: [architecture-standards]` |
| `spec-reviewer` | **opus** | high | 30 | `memory: project`, `skills: [architecture-standards]` |
| `spec-requirements-validator` | sonnet | high | 15 | `disallowedTools: Write, Edit, Bash` |
| `spec-design-validator` | sonnet | high | 20 | `disallowedTools: Write, Edit, Bash`, `skills: [architecture-standards]` |
| `spec-task-validator` | sonnet | high | 20 | `disallowedTools: Write, Edit, Bash` |
| `tdd-test-writer` | sonnet | — | 30 | Cannot read implementation files |
| `tdd-implementer` | sonnet | — | 40 | Cannot modify test files |
| `tdd-refactorer` | sonnet | high | 25 | — |
| `spec-task-executor` | sonnet | high | 50 | `skills: [architecture-standards]` |
| `task-completion-validator` | sonnet | high | 30 | `disallowedTools: Write, Edit` |
| `silent-failure-hunter` | sonnet | — | 25 | `background: true`, `disallowedTools: Write, Edit` |
| `acceptance-tester` | sonnet | high | 35 | Generates behavioral tests from EARS requirements |

## File Structure

```
spec-driven-dev/
├── default.nix
├── rules.md
├── README.md
├── hooks/
│   ├── session-start.sh
│   ├── post-compact.sh
│   ├── spec-awareness.sh
│   ├── protect-specs.sh
│   ├── spec-changelog.sh
│   └── task-completed.sh
├── 00-steering/
│   └── skills/spec-steering-setup/
│       ├── SKILL.md
│       └── templates/{product,tech,structure}.md.template
├── 01-discovery/
│   └── skills/interview/SKILL.md
├── 02-spec/
│   ├── agents/{system-architect,spec-{requirements,design,task}-validator}.md
│   └── skills/
│       ├── architecture-standards/
│       │   ├── SKILL.md
│       │   └── references/{adr-template,ddd-patterns}.md
│       ├── adr/SKILL.md
│       ├── spec-create/
│       │   ├── SKILL.md
│       │   └── templates/{requirements,design,tasks}.md.template
│       └── spec-status/SKILL.md
├── 03-implementation/
│   ├── agents/{tdd-test-writer,tdd-implementer,tdd-refactorer,spec-task-executor}.md
│   └── skills/{tdd-cycle,spec-execute}/SKILL.md
├── 04-quality/
│   ├── agents/{task-completion-validator,spec-reviewer,silent-failure-hunter,acceptance-tester}.md
│   ├── rules/quality-standards.md
│   └── skills/spec-mutate/SKILL.md
└── 05-bugs/
    └── skills/
        ├── bug-create/
        │   ├── SKILL.md (context: fork)
        │   └── templates/bug-report.md.template
        └── bug-fix/SKILL.md
```

## Design Decisions

**Skills over commands** — Commands are legacy in Claude Code. Skills support auto-triggering, supporting files, `context: fork`, and scoped hooks.

**`disable-model-invocation: true` on dangerous skills** — `spec-execute`, `bug-fix`, `tdd-cycle`, and other skills that modify code require explicit `/command` invocation.

**Only 2 Opus agents** — `system-architect` (cross-file architectural reasoning) and `spec-reviewer` (cross-file spec verification). All others use Sonnet with `effort: high` for ~60-70% cost savings with equivalent quality on structured tasks.

**`context: fork` on bug-create** — Bug investigation runs in an isolated subagent context. `spec-create` runs inline because it spawns validator agents (subagents can't spawn sub-subagents).

**Wave-based parallel execution** — Tasks without mutual dependencies run in parallel within a wave. Each task gets its own worktree. Passing tasks merge back in task-number order (rebase then merge) for clean linear history. Failed tasks are discarded. Next wave starts after the current one completes.

**Merge-in-order-then-rebase** — Even though tasks run in parallel, they merge sequentially by task number. Each subsequent task's worktree branch is rebased onto the updated feature branch before merging, ensuring a linear commit history.

**Auto-continue** — After each wave, spec-execute offers to continue. "Keep going" runs all remaining waves without waiting.

**Dual validation** — `task-completion-validator` agent checks code quality (stubs, error handling, test coverage). `TaskCompleted` hook checks build/tests deterministically. Defense in depth.

**Smart spec protection** — PreToolUse hook only warns about spec edits when implementation is underway (tasks started). During spec creation, edits flow freely.

**`memory: project`** on `system-architect` and `spec-reviewer` — accumulates architectural knowledge and review patterns across sessions.

**`background: true`** on `silent-failure-hunter` — runs concurrently without blocking.

**Architecture integrated into pipeline** — `system-architect` agent runs during spec-create Phase 2, creates ADRs for significant decisions. `architecture-standards` skill preloaded on executor, reviewer, and design validator via `skills` frontmatter.

**Template flexibility** — Templates are starting points. Irrelevant sections are omitted, not left as empty headers.

**EARS format for requirements** — Easy Approach to Requirements Syntax (When/While/Where/If → SHALL) makes every requirement unambiguous and directly testable.

**Confidence scores (0-100) on all agent outputs** — Enables automated phase gates.
