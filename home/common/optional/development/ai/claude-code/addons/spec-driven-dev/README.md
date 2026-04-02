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

`/spec-steering-setup` analyzes the project and creates three steering documents in `.claude/steering/`:

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

Each validator is **platform-enforced read-only** (opus, `effort: high`, `disallowedTools: Write, Edit, Bash`) and scores on weighted criteria (0-100). Human approval is required between each phase.

Templates are flexible — irrelevant sections are omitted, not left empty.

Specs are stored in `.claude/specs/{feature-name}/`. Templates are in `02-spec/skills/spec-create/templates/`.

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

`/spec-execute <feature> <N>` runs a single task from a spec:

1. Ensures we're on the `feature/{name}` branch (creates it if needed)
2. Finds the next incomplete task (or uses the specified task number)
3. Creates a **worktree** branched from the feature branch (each task gets its own branch)
4. Delegates to `spec-task-executor` agent (sonnet, `effort: high`) — runs in the worktree
5. Validates via `task-completion-validator` agent (opus, `effort: max`) — runs in the **same** worktree
6. On PASS: exits worktree, merges task branch back into feature branch
7. On FAIL: exits worktree, feature branch is untouched — retry the task
8. Offers to **auto-continue** to the next task ("keep going" runs all remaining)

**Git branch structure:**
```
main
  └── feature/my-feature              ← created by /spec-create
        ├── worktree-my-feature-task-1  ← merged back on PASS
        ├── worktree-my-feature-task-2  ← merged back on PASS
        └── ...                         ← PR: feature/my-feature → main
```

Pass `--no-worktree` to skip worktree isolation and work directly on the feature branch.

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

`/bug-create <description>` runs in a **forked context** to investigate the codebase, identify root cause, and write a structured report to `.claude/specs/bug-{slug}/bug-report.md` with fix tasks.

`/bug-fix <bug-slug>` implements the fix, adds a regression test, and validates via the completion validator.

## Hooks

Six hooks are configured automatically:

| Hook | Event | Behavior |
|------|-------|----------|
| `session-start.sh` | `SessionStart` | Loads steering context summary and active spec status once at session start. |
| `spec-awareness.sh` | `UserPromptSubmit` | Injects active spec status into every prompt. Suggests `/spec-create` when feature implementation is requested without a spec. |
| `protect-steering.sh` | `PreToolUse` (Edit/Write) | Advisory prompt when editing `.claude/steering/` files. |
| `protect-specs.sh` | `PreToolUse` (Edit/Write) | Advisory prompt when editing `requirements.md` or `design.md` during implementation. Prevents spec drift. `tasks.md` is allowed for marking completion. |
| `spec-changelog.sh` | `PostToolUse` (Edit/Write) | Tracks changes to spec documents by appending timestamped entries to `changelog.md` within the spec directory. Runs async. |
| `post-compact.sh` | `SessionStart` (matcher: `compact`) | Re-injects active spec context and current task details after auto-compaction. Prevents spec drift in long sessions. |

## Auto-Triggering

| Skill | Triggers On | User-Only |
|-------|------------|-----------|
| `interview` | "help me think through", "brainstorm", "let's discuss" | No — Claude suggests it |
| `spec-create` | "spec out", "plan", "design", "write a spec" | No — Claude suggests it |
| `spec-steering-setup` | — | Yes (`/spec-steering-setup` only) |
| `spec-status` | — | Yes (`/spec-status` only) |
| `tdd-cycle` | — | Yes (`/tdd-cycle` only) |
| `spec-execute` | — | Yes (`/spec-execute` only) |
| `spec-mutate` | — | Yes (`/spec-mutate` only) |
| `bug-create` | — | Yes (`/bug-create` only, runs in fork) |
| `bug-fix` | — | Yes (`/bug-fix` only) |

## Agent Configuration

All agents use calibrated frontmatter:

| Agent | Model | Effort | maxTurns | Isolation | Special |
|-------|-------|--------|----------|-----------|---------|
| `spec-requirements-validator` | opus | high | 15 | — | `disallowedTools: Write, Edit, Bash` |
| `spec-design-validator` | opus | high | 20 | — | `disallowedTools: Write, Edit, Bash` |
| `spec-task-validator` | opus | high | 20 | — | `disallowedTools: Write, Edit, Bash` |
| `tdd-test-writer` | sonnet | — | 30 | — | Cannot read implementation files |
| `tdd-implementer` | sonnet | — | 40 | — | Cannot modify test files |
| `tdd-refactorer` | opus | high | 25 | — | — |
| `spec-task-executor` | sonnet | high | 50 | — | Executes one task in worktree, marks complete, stops |
| `task-completion-validator` | opus | **max** | 30 | — | `disallowedTools: Write, Edit` |
| `spec-reviewer` | opus | high | 30 | — | `memory: project` (read-only via `tools` allowlist) |
| `silent-failure-hunter` | sonnet | — | 25 | — | `disallowedTools: Write, Edit` |
| `acceptance-tester` | sonnet | high | 35 | — | Generates behavioral tests from EARS requirements |

## File Structure

```
spec-driven-dev/
├── default.nix
├── rules.md
├── README.md
├── hooks/
│   ├── session-start.sh
│   ├── spec-awareness.sh
│   ├── protect-steering.sh
│   ├── protect-specs.sh
│   ├── spec-changelog.sh
│   └── post-compact.sh
├── 00-steering/
│   └── skills/spec-steering-setup/
│       ├── SKILL.md
│       └── templates/{product,tech,structure}.md.template
├── 01-discovery/
│   └── skills/interview/SKILL.md
├── 02-spec/
│   ├── agents/{requirements,design,task}-validator.md
│   └── skills/
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

**Skills over commands** — Commands are legacy in Claude Code. Skills support auto-triggering, supporting files (templates), `context: fork`, and scoped hooks.

**`disable-model-invocation: true` on dangerous skills** — `spec-execute`, `bug-fix`, `tdd-cycle`, and other skills that modify code require explicit `/command` invocation. Claude cannot auto-trigger them.

**`context: fork` on bug-create** — Bug investigation runs in an isolated subagent context to keep the main conversation clean. `spec-create` runs inline because it needs to spawn validator agents (subagents can't spawn sub-subagents).

**Feature branch + worktree-per-task** — `/spec-create` creates `feature/{name}` branch. Each `/spec-execute` task runs in a worktree branched from the feature branch. Passed tasks merge back; failed tasks are discarded. The result is a clean feature branch with one merge per task, ready for PR.

**Auto-continue** — After each task, spec-execute offers to continue. "Keep going" runs all remaining tasks without waiting.

**Platform-enforced read-only validators** — `disallowedTools: Write, Edit, Bash` on validators ensures they physically cannot modify files, regardless of prompt instructions.

**`effort` calibration** — `max` on `task-completion-validator` (zero-tolerance gate), `high` on opus validators and `spec-task-executor`, default on sonnet implementers.

**`maxTurns` on all agents** — Safety net against runaway costs. 15 for validators, 25-50 for implementers.

**`memory: project` on spec-reviewer** — Accumulates project patterns across reviews, improving effectiveness over time.

**Six lifecycle hooks** — SessionStart (context loading + post-compaction restoration), UserPromptSubmit (spec awareness), PreToolUse (steering/spec protection), PostToolUse (changelog tracking).

**Advisory hooks, not blocking** — PreToolUse hooks use `"permissionDecision": "ask"` rather than hard deny. This avoids friction for legitimate quick fixes.

**Template flexibility** — Templates are starting points. Irrelevant sections are omitted, not left as empty headers.

**EARS format for requirements** — Easy Approach to Requirements Syntax (When/While/Where/If → SHALL) makes every requirement unambiguous and directly testable.

**Confidence scores (0-100) on all agent outputs** — Enables automated phase gates. Validators fail when weighted average drops below thresholds.
