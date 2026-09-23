# Other Coding Assistants: Cursor, Copilot, Gemini CLI, Windsurf, Cline/Roo, Aider

## Contents
1. General rule
2. Cursor
3. GitHub Copilot
4. Gemini CLI
5. Windsurf / Codeium
6. Cline and Roo Code
7. Aider
8. Cross-platform generation checklist

## 1. General rule

These products change configuration surfaces frequently. Use this file as a conceptual adapter guide, not a frozen schema. Before generating files, check current official documentation and release notes for exact paths, precedence, scope, syntax, agent features, MCP support, hooks, and deprecations.

Never fabricate a native feature just to match the canonical manifest. If a host lacks a hard permission/hook/sandbox feature, state the limitation and move enforcement to an external wrapper, container, CI policy, or policy engine where possible.

## 2. Cursor

Typical concepts to verify:
- project rules and any directory/path-scoped rule mechanism;
- legacy `.cursorrules` vs current rule locations and migration guidance;
- agent/custom mode behavior;
- tool/MCP configuration;
- command/workflow features;
- repository indexing/context behavior.

Use project rules for stable repo guidance, scoped rules for component conventions, and explicit workflows for side-effectful actions. Keep external hard controls outside prompt-only rule files when the host cannot enforce them.

## 3. GitHub Copilot

Typical concepts to verify:
- repository custom instructions such as `copilot-instructions.md`-style files;
- path-specific/custom instruction capabilities;
- coding agent/agent-file support;
- MCP/extensions/tools;
- organization/repository policy controls;
- PR/issue automation and GitHub Actions integration.

For PR/issue agents, treat issue bodies, comments, and third-party action output as untrusted data. Enforce branch/repository permissions with GitHub-native protection and token scope, not prompt instructions alone.

## 4. Gemini CLI

Typical concepts to verify:
- project/user context instruction files (for example `GEMINI.md`-style surfaces if current);
- extension/tool/MCP support;
- sandbox/approval settings;
- command hooks/callbacks;
- session/context behavior.

Translate canonical project guidance, tools, approvals, and verification only after confirming current syntax and precedence.

## 5. Windsurf / Codeium

Typical concepts to verify:
- Rules;
- Workflows;
- Memories;
- MCP/tool integrations;
- agent/mode features;
- workspace vs user scope.

Keep durable repo truth in versioned rules/docs rather than opaque personal memory when teams need reproducibility. Use workflows for explicit repeatable procedures and reserve memories for user/session facts with clear provenance.

## 6. Cline and Roo Code

Typical concepts to verify:
- custom instructions;
- modes/personas with tool restrictions;
- workflows/commands;
- MCP servers;
- auto-approval/tool policy;
- checkpoints/task state.

Modes can be useful for concrete permission/context separation, such as read-only architect vs implementation mode. Avoid creating many cosmetic modes that share identical authority.

## 7. Aider

Aider is generally closer to a focused coding CLI than a full lifecycle agent platform. Verify current config/conventions options, repo-map behavior, model settings, Git integration, and command hooks.

Prefer external scripts/CI/policy wrappers for capabilities Aider does not natively enforce. Do not force subagent/hook concepts into a host that does not support them.

## 8. Cross-platform generation checklist

For each target:
- confirm the current config file path and scope;
- confirm nested precedence/merge behavior;
- confirm whether rule files are instructions or actual permission controls;
- confirm semantic vs manual invocation behavior;
- confirm tool/MCP permission semantics;
- confirm memory persistence and provenance controls;
- confirm what can be sandboxed natively;
- confirm how to represent explicit approval;
- confirm telemetry/eval options;
- note unsupported canonical requirements and compensating controls.
