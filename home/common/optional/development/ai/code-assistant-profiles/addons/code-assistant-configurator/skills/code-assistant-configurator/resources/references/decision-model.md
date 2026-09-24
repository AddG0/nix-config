# Primitive and Architecture Decision Model

## Contents
1. Design objective
2. Primitive selection table
3. Architecture selection
4. Trigger selection
5. Enforcement selection
6. When not to add a primitive
7. Common anti-patterns
8. Decision checklist

## 1. Design objective

Choose the smallest set of primitives that produces the desired behavior with explicit authority, observable effects, and testable completion. Optimize for clarity, least privilege, low context cost, and maintainability rather than feature count.

## 2. Primitive selection table

| Need | Prefer | Avoid using instead | Key test |
|---|---|---|---|
| Stable repo-wide coding/build conventions | Project instructions / repo rule | A skill that must trigger every turn | Does guidance apply broadly without activation? |
| Path- or component-specific conventions | Directory/path-scoped rule | Global mega-prompt | Does scope match only affected files? |
| Reusable expertise/procedure | Skill | Permanent project instructions | Can it be activated only when relevant? |
| User-timed workflow | Explicit command | Automatic semantic trigger | Must the user control when it happens? |
| Consequential operation | Explicit command + approval/policy | Autonomous skill invocation | Is there an external/durable effect? |
| Context/tool isolation | Subagent | More headings in one prompt | Does isolation reduce conflict or risk? |
| Independent review | Read-only subagent/evaluator | Self-review in same context only | Is independence valuable enough for cost? |
| Fixed ordered compliance/release steps | Deterministic workflow/state machine | Free-form agent loop | Is the path known in advance? |
| Event interception | Hook | Prompt reminder | Must behavior fire on a lifecycle event? |
| External capability | Typed tool / MCP | Natural-language instruction to “do it” | Can inputs/effects be validated? |
| Authorization | Permission/policy engine | “Never do X” prompt | Can forbidden action be mechanically blocked? |
| Blast-radius reduction | Sandbox/network/identity scope | Tool description alone | Is inaccessible resource truly unreachable? |
| Repeated exact transformation | Script | Re-generating logic each run | Is deterministic output preferable? |
| Durable factual/config context | Versioned project memory/reference | Transcript dump | Can source/provenance be maintained? |
| Working execution state | Typed run/session state | Long prose scratchpad | Can it be checkpointed/recovered? |
| Behavioral regression protection | Eval suite | Manual spot checks only | Can trigger/trajectory/outcome be asserted? |

## 3. Architecture selection

Default to one tool-using primary agent.

Add a specialist only if at least one is true:
- it needs materially different tools or permissions;
- its context would pollute or conflict with the primary context;
- work can execute independently in parallel with controlled merging;
- an independent reviewer/evaluator is valuable;
- it represents a meaningful trust or authority boundary;
- it requires a materially different model/cost profile.

Prefer deterministic workflow nodes when ordering, compliance, approval, or postconditions must not depend on model discretion.

### Recommended patterns

**Single engineer**
- best default for routine implementation, debugging, repository Q&A;
- simplest evaluation and state model.

**Manager + explorer/reviewer**
- use explorer for read-only repository discovery;
- use reviewer after changes for independent critique;
- do not spawn both for tiny changes automatically.

**Manager + implementers**
- use for separable modules or large migrations;
- require ownership boundaries and merge/conflict policy.

**Evaluator-optimizer**
- use when a verifier can provide objective feedback;
- cap cycles explicitly.

**Deterministic outer graph, agentic inner nodes**
- strongest fit for release, compliance, migration, deployment, or security-sensitive workflows.

## 4. Trigger selection

| Trigger | Use for | Avoid for |
|---|---|---|
| Semantic activation | Low-risk reusable expertise | Deployments, publication, destructive changes |
| Explicit command | User-timed workflows, side effects | Background checks that must always fire |
| Delegation | Specialist tasks | Hidden expansion of authority |
| Pre-tool hook | Authorization, policy, validation | General reasoning |
| Post-tool hook | Formatting, state update, audit, verification | Preventing an action that already happened |
| Session start | Safe environment/context initialization | Expensive unrelated loading |
| File/path change | Targeted reactive checks | Broad noisy automation |
| CI/webhook | Repository/service events | Local conversational-only behavior |
| Schedule | Recurring maintenance | Fast-changing conditional events without state |

For semantic routing, require positive and negative examples. Evaluate false-trigger and missed-trigger rates.

## 5. Enforcement selection

Use defense in depth. Match criticality to enforcement strength:

1. prompt/instruction — behavioral guidance;
2. schema/validator/guardrail — structured constraint;
3. permission/policy engine — allow/ask/deny authority;
4. pre-tool hook — last-mile interception;
5. sandbox/network/identity — resource isolation;
6. human approval — selected authority transition;
7. postcondition/rollback — verify and recover.

If a rule protects secrets, production data, protected branches, deployment, money, or irreversible resources, do not leave it at layer 1 only.

## 6. When not to add a primitive

Do not add a skill when a stable repo instruction is enough.
Do not add an agent when a function/tool call is enough.
Do not add a hook when the behavior can safely remain a normal verification step.
Do not add a tool when an existing narrow tool already provides the capability.
Do not add persistent memory for facts that should live in source control.
Do not add remote MCP access when local deterministic code is sufficient.
Do not add an approval for harmless routine reads/formatters; approval fatigue weakens meaningful approvals.

## 7. Common anti-patterns

- “Mega system prompt” that mixes policy, API docs, procedures, examples, and secrets.
- Agent proliferation: one agent per noun or role rather than per isolation need.
- Semantic auto-trigger for deployment/production mutation.
- Omnipotent shell/tool plus prompt-only restrictions.
- Duplicated rules in multiple files with no precedence/owner.
- Global rules for component-specific conventions.
- Auto-memory accumulating stale decisions without provenance or expiration.
- Hook chains with hidden side effects, no idempotency, or unclear timeouts.
- Tool schemas that hide external effects behind vague names.
- Self-reported success without executable verification.

## 8. Decision checklist

Before generating each primitive, answer:
- What exact requirement does this primitive satisfy?
- Why is a simpler primitive insufficient?
- What triggers it?
- What authority does it have?
- What context does it load?
- What can it mutate?
- How does it fail?
- How is it observed?
- How is it tested?
- What happens if it is removed?

If the last question has no meaningful answer, the primitive may be unnecessary.
