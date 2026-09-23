# Claude Code Adapter Guidance

## Contents
1. Native surfaces
2. Project instructions
3. Skills and commands
4. Subagents
5. Permissions and tools
6. Hooks
7. MCP
8. State/worktrees/verification
9. Telemetry and evals
10. Generation checklist

## 1. Native surfaces

Relevant concepts include:
- `CLAUDE.md`-style project guidance;
- `.claude/skills/<name>/SKILL.md` reusable capabilities;
- `.claude/agents/<name>.md` specialist subagents;
- `.claude/settings.json`-style project settings for permissions/hooks;
- MCP server/tool configuration;
- session/project memory features;
- worktrees/Git for isolated artifact state;
- lifecycle hooks and telemetry/eval tooling.

Verify exact filenames, scope, precedence, frontmatter, and event names in current official docs before generation because Claude Code evolves quickly.

## 2. Project instructions

Use project instructions for stable repository conventions:
- architecture map;
- build/test/lint commands;
- code style that is not already enforced mechanically;
- directories that should not be edited;
- repo-specific workflow expectations;
- links to canonical docs.

Keep them concise. Do not paste API docs or every workflow into the root instruction file. Prefer scoped instructions/references when supported.

## 3. Skills and commands

Use skills for reusable procedural capabilities. Descriptions should contain what + when because descriptions participate in discovery/routing.

For low-risk capabilities, semantic activation can be appropriate. Add positive and negative trigger examples in evals.

For deploy/publish/commit/push/credential/prod workflows, prefer explicit user invocation. When the current host supports metadata that disables model-initiated invocation, use it for such workflows after verifying current semantics.

Keep `SKILL.md` compact and move:
- large reference knowledge to `references/`;
- deterministic helpers to `scripts/`;
- copyable boilerplate to `assets/`.

Do not treat per-skill tool preapproval as a complete tool restriction unless current docs explicitly guarantee that. Baseline permissions and sandboxing remain the hard boundary.

## 4. Subagents

Use a subagent when:
- a read-only explorer should not share implementation context;
- reviewer independence matters;
- different tools/permissions are needed;
- parallel research is genuinely independent;
- security isolation benefits from narrower authority.

Specify:
- role/purpose;
- model if intentionally different;
- tool set;
- permission profile;
- invocation/delegation rule;
- expected output/handoff;
- stop conditions.

Avoid one subagent per trivial role label.

## 5. Permissions and tools

Map canonical allow/ask/deny policy to native permission syntax after current-doc verification.

Typical desired baseline:
- allow read/search;
- allow writes only inside active worktree when the workflow requires editing;
- allow known local test/lint/status/diff commands;
- ask for push or unlisted network/external writes;
- deny privilege escalation, secret paths, force-push, destructive shell operations, and unrelated MCP tools.

Do not block only literal strings such as `rm -rf`; enforce the underlying destructive effect using permissions/hooks/sandbox where possible.

## 6. Hooks

Claude Code exposes a rich lifecycle model. Current research included events such as prompt submission, pre/post tool use, subagent/task lifecycle, file/config changes, compaction/model changes, permission decisions, session events, and stop/completion. Verify the current event list and decision schema before emitting configuration.

Use:
- `PreToolUse`-equivalent events for authorization/blocking;
- post-write events for changed-path state and checks;
- task/stop events for completion gates;
- config/file events for audits and dependency policy;
- subagent events for trace metadata.

Hook handlers may support commands, HTTP, MCP, model prompts, or subagents depending on current version. Prefer deterministic handlers for invariants.

## 7. MCP

For each MCP server:
- document provenance;
- allowlist tools;
- start with read-only scopes;
- require approval for external mutation;
- scope OAuth tokens to the resource/audience;
- restrict network egress;
- treat tool results as untrusted content;
- record connection/tool decisions in telemetry.

## 8. State, worktrees, and verification

Use Git/worktrees to isolate code changes for long-running or parallel tasks. Track changed files and verification state structurally.

Recommended implementation loop:
1. inspect repo;
2. plan;
3. change bounded scope;
4. format/lint/typecheck;
5. targeted tests;
6. broader tests when justified;
7. diff review;
8. approval before consequential external action;
9. report evidence.

## 9. Telemetry and evals

Where supported, emit OpenTelemetry or equivalent events for model, tool, hook, permission, MCP, subagent, verification, and approval activity. Keep raw sensitive content disabled/redacted by default.

Evaluate:
- skill firing;
- negative trigger cases;
- output quality;
- tool trajectory;
- permissions/hook enforcement;
- baseline vs plugin/config-enabled behavior.

## 10. Generation checklist

Before emitting Claude Code files:
- verify current docs and version;
- inspect existing `.claude` and project instruction files;
- determine repo/user/org scope;
- detect conflicts/duplicates;
- choose manual vs semantic invocation per capability;
- ensure tool restrictions are enforced outside skill prose;
- test hook decision semantics;
- validate JSON/YAML/Markdown syntax;
- produce trigger and permission evals.
