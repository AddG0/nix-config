# OpenAI / ChatGPT / Codex / Agents SDK Adapter Guidance

## Contents
1. Scope
2. ChatGPT / Agent Skills
3. Repository instructions for coding agents
4. Agents SDK architecture
5. Tools and guardrails
6. Sessions/state/memory
7. Human approval
8. Tracing and evals
9. Generation checklist

## 1. Scope

OpenAI coding/agent workflows span more than one product surface. Do not assume ChatGPT Skills, Codex repository instructions, and Agents SDK application code share identical metadata or precedence. Verify the specific target and current official documentation before generation.

## 2. ChatGPT / Agent Skills

For ChatGPT-style Skills in this environment:
- package a directory with `SKILL.md`;
- use YAML frontmatter containing only `name` and `description` for maximum compatibility with the local Skill creator rules;
- put all trigger language in the description;
- keep the body compact and imperative;
- place large details in one-level `references/`;
- place deterministic helpers in `scripts/`;
- place final-output boilerplates/assets in `assets/`;
- include `agents/openai.yaml` UI metadata when required by the host packaging flow;
- validate/package with the host's Skill validator when available.

The broader Agent Skills standard may allow additional metadata. Do not add fields to a ChatGPT Skill unless the target host accepts them.

## 3. Repository instructions for coding agents

When the target supports repository instruction files such as `AGENTS.md`, use them for stable repo guidance rather than embedding every workflow in the application prompt.

Verify:
- discovery locations;
- nested/directory scope;
- precedence/merge rules;
- whether multiple files combine or override;
- interaction with user/system/developer instructions.

Keep build/test commands and architecture references accurate to the live repo.

## 4. Agents SDK architecture

Canonical concepts map naturally to:
- `Agent` definitions for primary/specialists;
- function tools and MCP tools for capabilities;
- manager/handoff patterns for orchestration;
- input/output/tool guardrails for validation and policy;
- sessions for working context;
- explicit application state/checkpoints where needed;
- human-in-the-loop approval for selected tools/effects;
- tracing for runs/tools/delegation.

Start single-agent. Add handoffs/specialists only for concrete tool/context/parallel/security boundaries.

## 5. Tools and guardrails

Use typed function schemas. Separate read and mutation tools when authority differs.

Place security enforcement immediately around tool execution:
- validate arguments;
- authorize resource/effect;
- request approval if needed;
- execute in sandbox/proxy;
- verify postconditions;
- trace decision/result.

Do not depend solely on input classifiers at conversation start; a dangerous tool call can arise several steps later.

## 6. Sessions, state, and memory

Use sessions for conversational/run continuity, but keep durable code truth in files/Git and operational truth in typed application state. For long-lived semantic stores, define provenance and retention.

Avoid growing a session transcript into a de facto unbounded memory store.

## 7. Human approval

For side-effectful tools, bind approval to a server-owned pending action. Show exact operation/resource/effect and verification status. Do not trust client-supplied identifiers as proof that an action was approved.

Resume the paused run only after a valid approval/rejection decision.

## 8. Tracing and evals

Trace:
- agent selection/handoffs;
- model calls;
- tool inputs at a privacy-safe level;
- guardrail decisions;
- approvals;
- state transitions;
- verification;
- outcome.

Evaluate both final output and tool trajectory. Include direct tests of tool guardrails without invoking a model.

## 9. Generation checklist

- identify ChatGPT Skill vs Codex/repo-instruction vs Agents SDK target;
- verify current official schemas;
- keep higher-authority instructions separate from user/tool data;
- use typed tools;
- define approvals for external effects;
- define sessions/state explicitly;
- generate eval cases for routing, tool use, guardrails, approval, and outcome;
- validate Skill package when producing a ChatGPT Skill.
