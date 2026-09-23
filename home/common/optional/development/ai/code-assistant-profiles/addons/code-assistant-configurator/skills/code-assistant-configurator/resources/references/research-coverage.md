# Research Coverage and Traceability

This file maps the major research themes to the implementation so updates do not silently drop coverage.

## Coverage matrix

| Research topic | Where implemented |
|---|---|
| Layered agent architecture | `SKILL.md` core rules/workflow; `decision-model.md` |
| Single-agent-first / multi-agent criteria | `SKILL.md`; `decision-model.md` |
| Deterministic workflow vs agent | `decision-model.md`; `canonical-schema.md` |
| Manager/specialists, parallel workers, evaluator-optimizer | `decision-model.md`; `canonical-schema.md` |
| Skills as progressive procedural packages | `SKILL.md`; `context-memory.md`; platform refs |
| Triggering: semantic, explicit, delegated, lifecycle, CI/webhook, schedule | `SKILL.md`; `decision-model.md`; `hooks-tools.md` |
| Rules/instruction precedence | `context-memory.md`; platform refs |
| Positive vs negative trigger examples | `SKILL.md`; `evaluation.md` |
| Hooks and lifecycle events | `hooks-tools.md`; Claude Code platform ref |
| Hook idempotency, timeouts, failure/exit semantics | `hooks-tools.md` |
| Tools, schemas, effects, risk classes | `SKILL.md`; `canonical-schema.md`; `hooks-tools.md` |
| MCP/tool trust and least privilege | `security.md`; `hooks-tools.md`; platform refs |
| Permission allow/ask/deny concepts | `security.md`; `canonical-schema.md` |
| Sandbox/filesystem/network boundaries | `security.md`; `canonical-schema.md` |
| Scoped/short-lived credentials | `security.md` |
| Prompt injection / untrusted repo and tool content | `security.md`; `context-memory.md` |
| State classes and memory | `context-memory.md`; `canonical-schema.md` |
| Git/worktrees as durable code state | `context-memory.md`; Claude Code ref |
| Context windows / lean context / progressive loading | `context-memory.md` |
| Monorepo context strategy | `context-memory.md` |
| Custom commands/workflows | `SKILL.md`; platform refs |
| Verification loops: format/lint/typecheck/test/diff | `SKILL.md`; `evaluation.md` |
| Human approval at consequential boundaries | `SKILL.md`; `security.md`; `canonical-schema.md` |
| Observability / tracing / audit | `SKILL.md`; `evaluation.md`; `canonical-schema.md` |
| Sensitive telemetry redaction | `security.md`; `evaluation.md` |
| Trigger/outcome/trajectory/security evals | `evaluation.md` |
| False-trigger / missed-trigger metrics | `evaluation.md` |
| Cost/latency/tool-call budgets | `evaluation.md`; `canonical-schema.md` |
| Failure, retry, rollback, partial status | `SKILL.md`; `canonical-schema.md`; `evaluation.md` |
| Platform portability without false equivalence | `platform-matrix.md`; platform refs |
| Claude Code native surfaces | `platform-claude-code.md` |
| OpenAI/ChatGPT/Codex/Agents SDK surfaces | `platform-openai.md` |
| Cursor/Copilot/Gemini/Windsurf/Cline/Roo/Aider | `platform-other-assistants.md` |
| Agent Skills format | `platform-matrix.md`; `platform-openai.md`; generated-skill validator |
| Canonical source-of-truth manifest | `canonical-schema.md`; `assets/canonical-manifest.yaml` |
| Config-generation inputs | `SKILL.md` step 1; `canonical-schema.md` |
| Decision logic for what NOT to generate | `decision-model.md` |
| Secure defaults | `security.md`; templates/assets |
| Best practices / anti-patterns | `SKILL.md`; `decision-model.md`; all refs |
| Current-doc / version drift handling | `SKILL.md`; `platform-matrix.md` |
| Deterministic validation | `scripts/validate_manifest.py`; `scripts/validate_generated_skill.py` |
| Repository discovery | `scripts/inspect_repo.py` |

## Maintenance rule

When updating this skill after new research or platform changes:
1. add or update the relevant platform/reference behavior;
2. update any affected templates or validators;
3. add/modify eval guidance for the changed behavior;
4. update this coverage map;
5. re-run skill packaging validation and the bundled scripts' self-tests.
