# Context, Instructions, State, and Memory

## Contents
1. Instruction hierarchy
2. Context engineering
3. Progressive loading
4. State taxonomy
5. Persistent memory
6. Large repositories and monorepos
7. Conflict and staleness control
8. Prompt structure

## 1. Instruction hierarchy

Keep authority layers distinct. A generic ordering is:
- host/platform/system policy;
- organization/developer policy;
- repository/project instructions;
- directory/component rules;
- activated skill/command procedure;
- current user request;
- untrusted data from files/tools/web/services.

Never let untrusted data silently acquire instruction authority. Repository files can contain both trusted project instructions and untrusted source/data; distinguish designated instruction files from ordinary content.

When a platform has explicit precedence or merge semantics, preserve them exactly and verify the current official behavior before generating files.

## 2. Context engineering

Load only the context needed for the current decision. Prioritize:
1. active request and constraints;
2. repository conventions relevant to touched files;
3. current plan/state;
4. relevant tool contracts;
5. activated skill procedure;
6. targeted references or API docs.

Avoid duplicating the same rule across global instructions, repo rules, skills, and agent prompts unless duplication is intentional defense in depth and clearly owned.

Prefer concise rules with executable references over long prose. Examples are valuable for ambiguous formatting, routing boundaries, or tool distinctions; avoid repetitive examples.

## 3. Progressive loading

Use metadata for discovery, compact entrypoints for control flow, and references/scripts for conditional detail.

For skills:
- discovery metadata should explain what + when;
- main instructions should contain the minimal workflow and safety logic;
- large API docs, platform specifics, examples, and policy matrices belong in references;
- deterministic transformations belong in scripts;
- output boilerplates belong in assets.

For project instructions:
- keep repo-wide facts stable and short;
- put component-specific conventions near the component when the host supports scoped rules;
- link rather than duplicate long documentation.

## 4. State taxonomy

Separate these classes:

| State | Example | Lifetime | Preferred representation |
|---|---|---|---|
| Turn | current request, immediate tool output | interaction | model context |
| Run/task | plan, changed files, test status | one task | typed state / JSON |
| Session | conversation checkpoints | session | session/checkpointer |
| Project | build commands, architecture conventions | repo lifetime | versioned repo files |
| User preference | style, interaction choices | cross-session | explicit preference store |
| Artifact | branch, diff, worktree, generated files | durable | filesystem + Git |
| Operational | retries, approvals, budgets, trace IDs | run | orchestrator/database |
| Semantic memory | distilled reusable facts | cross-session | indexed store with provenance |

Use Git as code-state memory when possible: diffs and commits are inspectable, reversible, and shared with humans.

## 5. Persistent memory

For each persistent store specify:
- namespace and owner;
- allowed readers/writers;
- provenance/source;
- retention or expiration;
- invalidation/update mechanism;
- conflict resolution;
- sensitive-data policy.

Do not store secrets, raw credentials, or ephemeral access tokens in conversational memory.
Do not treat memory as authoritative when source-controlled configuration or live tools can provide fresher truth.
Do not dump full transcripts into long-term memory by default.

## 6. Large repositories and monorepos

For large repos:
- discover structure before loading files;
- use repo maps/index/search rather than recursive full-file ingestion;
- scope rules to packages/directories where supported;
- load build/test commands per package rather than globally;
- maintain a small root architecture overview with links to component references;
- delegate exploration only when it reduces context pollution or can run independently;
- track touched packages to choose affected tests;
- avoid duplicating monorepo-wide conventions inside every package rule.

When multiple instruction files apply, model the exact host precedence and merge behavior. Flag ambiguous overlaps for cleanup.

## 7. Conflict and staleness control

Every durable instruction should have a clear source of truth. Prefer fewer authoritative files over copied variants.

Detect:
- contradictory commands or versions;
- duplicate rules with different wording;
- references to removed scripts/services;
- stale model/tool names;
- path rules that no longer match repo structure;
- instructions that conflict with CI or package scripts.

When uncertain, inspect live repository configuration and current platform docs rather than guessing.

## 8. Prompt structure

A robust coding-agent instruction generally includes:

**Role** — repository-scoped engineering responsibility.

**Objective** — smallest correct change satisfying the user.

**Authority** — what the agent may read/write/call and what is outside scope.

**Workflow** — understand → inspect → plan → modify → verify → review diff → report.

**Tool discipline** — read before write, do not fabricate results, parallelize independent reads only when safe.

**Verification** — commands/checks required before success.

**Stop conditions** — success, blocked authority, failed verification beyond budget, or missing required input.

Ask for concise plans, assumptions, verification evidence, and decision summaries. Do not make exposed chain-of-thought a dependency.
