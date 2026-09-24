# Cross-Platform Mapping and Portability

## Contents
1. Portability rule
2. Conceptual mapping
3. What should remain canonical
4. Translation rules
5. Version drift and verification
6. Platform selection checklist

## 1. Portability rule

Map intent and security semantics, not vocabulary. A “rule,” “skill,” “agent,” or “tool” on one host may have different trigger, scope, context, or permission behavior on another.

Before generating target-native files, verify current official documentation for:
- file names and locations;
- scope and precedence;
- merge/override semantics;
- automatic vs explicit invocation;
- metadata/frontmatter fields;
- hook lifecycle events and decision formats;
- tool/MCP permission behavior;
- experimental/deprecated features.

## 2. Conceptual mapping

| Canonical concept | Claude Code | OpenAI / ChatGPT / Codex / Agents SDK | Cursor | GitHub Copilot | Gemini CLI | Windsurf | Cline / Roo | Aider / generic |
|---|---|---|---|---|---|---|---|---|
| Project instructions | `CLAUDE.md` and scoped instructions | repo instructions such as `AGENTS.md` where supported; application instructions in SDK | project/directory rules | repository custom instructions | context/instruction files | rules | custom instructions/modes | conventions/config prompt |
| Reusable skill | `.claude/skills/.../SKILL.md` | ChatGPT/Agent Skills-style package where supported | reusable rule/workflow features vary | skills/agents/extensions vary | extensions/tools vary | workflows/rules vary | modes/workflows | prompt conventions/scripts |
| Specialist agent | `.claude/agents/*.md` | SDK `Agent`, handoffs/manager patterns | agent/mode features vary | coding agents/agent files vary | agents/subagents vary | modes/agents vary | modes | usually external orchestration |
| Explicit command | slash/custom command or manual skill invocation | app command/workflow | commands/features vary | prompts/actions vary | commands | workflows | commands/workflows | CLI flags/macros |
| Hook | lifecycle hooks | app/tool guardrails/middleware/orchestrator callbacks | platform automation varies | actions/hooks/CI around agent | callbacks/hooks vary | hooks/workflows vary | hooks/tool policy varies | shell/git hooks externally |
| Tool | built-ins + MCP | function tools + MCP | built-ins + MCP | tools/extensions + MCP | tools/MCP | tools/MCP | tools/MCP | shell/editor/tooling |
| Permission | allow/ask/deny + tool rules | application policy/guardrails/approval | platform rules | host/org/repo controls | host permissions | platform permissions | mode/tool permissions | shell/environment controls |
| Sandbox | host sandbox/worktree/environment | app/container/host sandbox | host/IDE environment | service/runner environment | local/runner sandbox | host environment | local/remote runtime | external runtime |
| Memory/state | project instructions, auto-memory, session/worktree | sessions/state/store + files | memories/rules | workspace/repo context | context/memory features | memories | task/mode context | repo map/chat history |
| Eval | plugin/task evals + external tests | SDK/app evals + external suites | external task suite | CI/evals | external evals | external evals | external evals | external evals |

Entries marked “vary” are intentionally conceptual. Verify exact current product features before emitting files.

## 3. What should remain canonical

Keep these semantics platform-neutral:
- purpose/non-goals;
- risk/effect classes;
- trigger intent;
- approval boundaries;
- tool resource scope;
- trust model;
- state classes;
- verification requirements;
- budgets/retry/failure behavior;
- observability/privacy policy;
- eval cases.

Translate only the representation.

## 4. Translation rules

### Instructions
If the host has repo-wide and directory-scoped instructions, place stable global guidance at the highest useful scope and component-specific guidance as close as possible to the component.

### Skills
Preserve:
- what + when description;
- manual vs automatic invocation;
- required tools;
- procedural workflow;
- resource references;
- trigger examples/evals.

Do not assume a skill's tool list is a security boundary unless the host explicitly says it is.

### Agents
Preserve:
- context isolation reason;
- tool/permission scope;
- delegation rule;
- handoff/output contract;
- concurrency/termination behavior.

### Hooks
Preserve:
- exact lifecycle moment;
- matcher;
- blocking vs observational semantics;
- timeout/failure mode;
- machine-readable decision output.

### Tools/MCP
Preserve:
- typed inputs/outputs;
- effects/risk;
- auth scopes;
- network/resource scope;
- approval requirements;
- result trust classification.

## 5. Version drift and verification

Before native generation:
1. check the target's official current docs/release notes;
2. identify the exact config surface and version;
3. flag deprecated/experimental behavior;
4. update syntax without weakening canonical policy;
5. note any canonical feature the host cannot enforce;
6. compensate using external sandbox/policy/orchestration when possible.

Never invent unsupported native controls. State the gap and provide the closest enforceable alternative.

## 6. Platform selection checklist

- What assistant/runtime will execute the config?
- Is configuration repo-local, user-local, organization-level, or service-side?
- Does it support nested/path-scoped rules?
- Does it support skills/progressive loading?
- Does it support specialist agents and separate tool scopes?
- Are hooks blocking or observational?
- Are tool permissions actual restrictions or only preapprovals?
- Can the runtime sandbox filesystem/network/processes?
- How are MCP/remote tools authenticated?
- Can runs pause/resume for approval?
- What state survives sessions?
- What telemetry/evals are native vs external?
