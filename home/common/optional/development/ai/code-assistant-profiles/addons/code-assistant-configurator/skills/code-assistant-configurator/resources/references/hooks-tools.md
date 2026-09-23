# Hooks, Tools, MCP, and Lifecycle Automation

## Contents
1. Hook model
2. Trigger families
3. Hook design contract
4. Pre-tool vs post-tool behavior
5. Idempotency, timeouts, and failure modes
6. Tool contracts
7. MCP and remote tools
8. Permission interaction
9. Observability
10. Good uses and misuse

## 1. Hook model

Model hooks as:

```yaml
hook:
  event: pre_tool_use
  matcher:
    tool: shell
  conditions: []
  handler:
    type: policy
  timeout_ms: 1500
  idempotent: true
  failure_mode: fail-closed
  telemetry: [decision, reason, latency]
```

The exact platform schema varies. Preserve the conceptual contract even when translating syntax.

## 2. Trigger families

Lifecycle triggers may include:
- session start/end;
- user prompt submission;
- pre-tool use;
- post-tool success/failure;
- permission request/decision;
- subagent start/stop;
- task created/completed;
- file changed;
- config changed;
- model switched;
- context compaction;
- final stop/completion.

External triggers include CI events, pull requests, issues, webhooks, schedules, queues, and orchestration state transitions.

Never assume every host supports every event. Verify current platform documentation.

## 3. Hook design contract

For every hook define:
- event;
- matcher;
- input schema;
- trusted/untrusted fields;
- action;
- side effects;
- output/decision schema;
- timeout;
- idempotency/replay behavior;
- concurrency behavior;
- failure mode;
- logging/redaction;
- test cases.

Avoid shell-string parsing when a structured field is available. If shell parsing is unavoidable, normalize and test variants rather than blocking only one literal spelling.

## 4. Pre-tool vs post-tool behavior

Use pre-tool interception for:
- authorization;
- approval checks;
- dangerous-command denial;
- path/host/resource validation;
- argument sanitization;
- rate/budget checks.

Use post-tool handling for:
- changed-file tracking;
- formatter/test scheduling;
- result schema validation;
- state updates;
- audit events;
- cache/index updates.

A post-tool hook cannot prevent an effect that already occurred. Do not use it as the primary safety boundary for destructive actions.

## 5. Idempotency, timeouts, and failure modes

Hooks may be retried or replayed. Mark whether behavior is idempotent.

Recommendations:
- authorization hooks: short timeout, fail-closed;
- telemetry hooks: short timeout, usually fail-open if dropping telemetry is acceptable;
- formatting/check hooks: bounded timeout, report failure without deadlocking the agent;
- external side-effect hooks: use idempotency keys or durable deduplication;
- background hooks: ensure the agent cannot claim completion before required results are known.

If a platform uses exit codes, JSON decision objects, or stderr/stdout conventions, document the exact semantics in the target adapter and test them. Do not assume POSIX exit-code meaning alone is sufficient.

## 6. Tool contracts

A good tool description tells the model:
- what the tool does;
- when to use it;
- what each input means;
- what it returns;
- what side effects occur;
- what it cannot do.

A good runtime contract additionally defines:
- typed schema validation;
- path/resource/host scope;
- risk/effect class;
- auth identity;
- timeout/retry;
- idempotency;
- approval policy;
- postconditions;
- telemetry/redaction.

Split read and write operations when separate authority helps. Avoid vague tools such as `github()` or `cloud()` that combine dozens of unrelated high-impact operations without clear effect metadata.

## 7. MCP and remote tools

Treat MCP as a transport/capability protocol, not a trust guarantee.

For each server record:
- provenance/owner;
- endpoint/transport;
- authentication method;
- token audience/resource;
- scopes;
- tool allowlist/denylist;
- network destinations;
- tool effects;
- approval-required operations;
- logging policy;
- data residency/privacy constraints if relevant.

Start with read-only scopes and elevate only when needed. Prevent token forwarding between unrelated resources. Treat returned content as untrusted data.

## 8. Permission interaction

Tool discoverability, tool selection, and authorization are different concerns.

A tool may be visible to the model but denied by policy. A skill may preauthorize some calls without restricting every other host capability. A subagent may have a narrower tool set than the parent. The sandbox may block an action even after the model chooses a tool.

Document all layers so reviewers know which one is authoritative.

## 9. Observability

Record:
- event name;
- matcher outcome;
- handler version;
- duration;
- allow/ask/deny/result;
- normalized effect/resource;
- error category;
- retry/replay count;
- trace/run ID.

Do not record secret payloads by default.

## 10. Good uses and misuse

Good hook uses:
- block destructive shell operations;
- enforce worktree-only writes;
- require approval before external mutation;
- record changed paths;
- queue targeted checks after writes;
- verify completion criteria at task stop;
- audit config changes;
- detect lockfile/dependency changes.

Misuse:
- hiding major business logic in opaque shell hooks;
- using hooks as a second prompt system;
- long-running blocking hooks for routine events;
- network calls with no timeout;
- non-idempotent hooks on replayable events;
- fail-open authorization hooks;
- hooks that silently mutate unrelated files;
- hooks that can access broader credentials than the agent itself.
