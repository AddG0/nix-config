# Canonical Assistant Configuration Schema

## Contents
1. Why use a canonical manifest
2. Top-level schema
3. Identity and purpose
4. Architecture and agents
5. Skills and commands
6. Tools and effects
7. Permissions, policy, and approvals
8. State and memory
9. Hooks and workflows
10. Verification
11. Budgets and failure handling
12. Observability and evals
13. Compatibility and provenance
14. Example manifest

## 1. Why use a canonical manifest

Use one portable source of truth for intent, authority, triggers, state, verification, and tests. Platform files are adapters. This prevents security semantics from being lost when changing hosts and makes review/evaluation possible without reverse-engineering many native files.

Use the canonical layer when:
- the system spans multiple native files;
- more than one assistant/platform is targeted;
- security, approvals, hooks, or external tools matter;
- multiple agents/skills exist;
- production/CI automation is involved;
- the configuration needs durable governance/versioning.

Skip it for a tiny single-file rule edit when it adds no value.

## 2. Top-level schema

Recommended logical fields:

```yaml
api_version: assistant.config/v1
kind: CodeAssistant
metadata: {}
spec:
  purpose: ""
  non_goals: []
  risk_class: bounded-write
  inputs: {}
  outputs: {}
  instructions: {}
  model_policy: {}
  invocation: {}
  architecture: {}
  skills: []
  commands: []
  tools: []
  policies: []
  permissions: {}
  sandbox: {}
  credentials: {}
  state: {}
  memory: {}
  hooks: []
  verification: {}
  approvals: []
  budgets: {}
  retries: {}
  failure: {}
  observability: {}
  evals: {}
  dependencies: {}
  compatibility: {}
  release: {}
```

## 3. Identity and purpose

`metadata` should include when useful:
- `name` — stable machine identifier;
- `display_name` — human label;
- `version` — config version;
- `owner` — maintainer/team;
- `provenance` — generated-from source, repo, ticket, research, or human owner;
- `created_at`/`updated_at` if the host uses them;
- `policy_bundle_version`, `tool_contract_version`, or related bundle IDs for production systems.

`purpose` should state the positive goal. `non_goals` should explicitly exclude tempting scope expansion such as deploy, protected-branch push, cloud mutation, or unrelated filesystem access.

Also capture `risk_class`, typed or described `inputs`/`outputs`, stable `instructions` or instruction references, and `model_policy` (model class, reasoning/effort profile, fallback/cost policy) when these affect behavior. Do not use model choice as a substitute for permissions or verification.

## 4. Architecture and agents

Represent architecture explicitly:

```yaml
architecture:
  type: single-agent  # or manager-specialists, workflow, hybrid, parallel, evaluator-optimizer
  primary: engineer
  agents:
    engineer:
      role: implementation coordinator
      model_policy: balanced
      tools: [repo-read, repo-write, shell-safe]
      permissions_profile: implementer
    explorer:
      role: read-only repository exploration
      invocation: delegated
      tools: [repo-read, search]
      permissions_profile: read-only
    reviewer:
      role: independent post-change review
      invocation: delegated
      tools: [repo-read, diff]
      permissions_profile: read-only
```

For every non-primary agent capture:
- concrete reason it exists;
- context boundary;
- tool/permission differences;
- delegation/trigger rule;
- completion/handoff contract;
- concurrency behavior;
- model/cost policy if applicable.

If the only difference is a role name, do not create a separate agent.

## 5. Skills and commands

Skill entry:

```yaml
skills:
  - id: code-review
    description: >-
      Review source-code changes for correctness, security, maintainability,
      and regressions. Use when asked to review a diff, patch, branch, or PR.
    invocation: semantic
    positive_examples:
      - "Review this PR."
    negative_examples:
      - "Implement this feature."
    inputs: [diff_or_repo_context]
    outputs: [findings]
    tools: [repo-read, diff]
    verification: [evidence-linked-findings]
    failure: return-partial-with-gaps
```

Command/workflow entry:

```yaml
commands:
  - id: deploy-staging
    invocation: explicit
    side_effect: external-write
    approval: always
    workflow: [build, test, summarize, approve, deploy, health-check]
```

Use commands for user-timed workflows and consequential operations. Use skills for reusable expertise/procedures where semantic activation is appropriate.

## 6. Tools and effects

Each tool contract should expose effects and authority, not just a name:

```yaml
tools:
  - id: apply-patch
    purpose: Apply a bounded patch inside the active worktree.
    input_schema:
      type: object
      required: [patch]
      properties:
        patch: {type: string}
    output_schema:
      type: object
      properties:
        changed_paths: {type: array}
        applied: {type: boolean}
    effects: [filesystem-write]
    risk: reversible-write
    idempotent: false
    scope:
      paths: ["${WORKTREE}/**"]
      network: none
    timeout_seconds: 30
    retry:
      max_attempts: 1
    authorization:
      default: allow
      deny_paths: ["**/.ssh/**", "**/.aws/**", "**/.env"]
    postconditions:
      - changed-paths-within-scope
    telemetry:
      arguments: redacted
      changed_paths: true
```

Recommended effect vocabulary:
- `filesystem-read`
- `filesystem-write`
- `process-execution`
- `network-read`
- `external-write`
- `publish`
- `deploy`
- `delete`
- `credential-change`
- `production-mutation`

Recommended risk classes:
- `read-only`
- `reversible-write`
- `external-side-effect`
- `destructive`
- `privileged`

## 7. Permissions, policy, and approvals

Represent authorization separately from tool availability:

```yaml
permissions:
  default: ask
  allow:
    - tool: repo-read
    - tool: repo-write
      paths: ["${WORKTREE}/**"]
    - tool: shell
      operations: [git-status, git-diff, project-test, project-lint]
  deny:
    - path: "${HOME}/.ssh/**"
    - path: "${HOME}/.aws/**"
    - operation: force-push
    - operation: sudo
  ask:
    - operation: git-push
    - network: unlisted
```

Policy precedence should normally be:
1. hard deny;
2. required approval;
3. explicit allow;
4. conservative fallback ask/deny based on environment.

Approvals should state:
- operation/effect;
- who can approve;
- context shown to approver;
- whether decision is one-time or reusable;
- timeout/expiry;
- audit record;
- resume behavior after approval.

## 8. State and memory

```yaml
state:
  run:
    fields:
      - plan
      - changed_files
      - verification_status
      - approvals
      - retry_count
  session:
    checkpoint: true
  artifact:
    mechanism: git-worktree

memory:
  project:
    source: repository-instructions
    write: controlled
    provenance_required: true
  user_preferences:
    write: explicit-only
  semantic:
    enabled: false
```

For each memory store define retention, provenance, readers, writers, invalidation, and sensitive-data policy.

## 9. Hooks and workflows

Hook shape:

```yaml
hooks:
  - id: shell-policy
    event: pre_tool_use
    matcher:
      tool: shell
    conditions: []
    action:
      type: policy-check
    failure_mode: fail-closed
    timeout_ms: 1500
    idempotent: true
    telemetry: [decision, latency]
```

Workflow shape:

```yaml
workflow:
  states: [inspect, plan, implement, verify, review, complete, partial]
  transitions:
    - from: inspect
      to: plan
    - from: plan
      to: implement
    - from: implement
      to: verify
    - from: verify
      to: implement
      when: fixable-failure-and-budget-remains
    - from: verify
      to: review
      when: checks-pass
    - from: review
      to: complete
      when: clean
```

## 10. Verification

```yaml
verification:
  required_before_success: true
  steps:
    - name: format
      command_source: repository
      failure: fix-and-retry
    - name: lint
      command_source: repository
      failure: fix-and-retry
    - name: typecheck
      command_source: repository
      optional_if_unavailable: true
    - name: tests
      scope: affected-first
      failure: diagnose-and-retry
    - name: diff-review
      mode: independent-when-high-risk
  unavailable:
    status: partial
    require_disclosure: true
```

Verification is evidence. Do not mark complete if required checks fail.

## 11. Budgets and failure handling

```yaml
budgets:
  max_tool_calls: 100
  max_fix_cycles: 3
  wall_clock_minutes: 30
  token_budget: null
  cost_budget_usd: null

retries:
  transient_tool_error:
    max_attempts: 2
    backoff: exponential
  verification_failure:
    max_attempts: 3

failure:
  authorization_error: fail-closed
  test_failure: retry-within-budget
  missing_dependency: partial-with-disclosure
  budget_exhausted: partial-result
  unsafe_or_ambiguous_authority: stop-and-escalate
```

Avoid unlimited retries. Distinguish transient infrastructure errors from deterministic policy failures.

## 12. Observability and evals

```yaml
observability:
  tracing: true
  routing_events: true
  tool_events: true
  policy_decisions: true
  approval_events: true
  verification_events: true
  changed_resources: true
  sensitive_content: false
  redaction: enabled

evals:
  trigger: true
  negative_trigger: true
  trajectory: true
  outcome: true
  permission: true
  adversarial: true
  failure_recovery: true
  performance: true
```

Trace config/model/skill versions so behavior is reproducible.

## 13. Compatibility and provenance

Capture:
- host/platform;
- minimum/maximum supported version if known;
- experimental/deprecated features;
- required binaries/runtimes;
- MCP servers and auth modes;
- network assumptions;
- operating-system assumptions;
- repo language/framework constraints.

For current platforms, verify official documentation at generation time rather than freezing brittle precedence/file-path assumptions in the canonical layer.

For production systems, version the whole release bundle, not only the prompt or model:

```yaml
release:
  assistant_config: 3.4.1
  skills_bundle: 7.2.0
  policy_bundle: 5.1.3
  tool_contracts: 4.0.2
  eval_suite: 9.3.0
  sandbox_image: "sha256:..."
```

This makes behavior reproducible across config, policy, tools, tests, and execution environment.

## 14. Example manifest

```yaml
api_version: assistant.config/v1
kind: CodeAssistant
metadata:
  name: repo-engineer
  version: 1.0.0
  owner: platform-engineering
spec:
  purpose: Implement and verify bounded code changes in the current repository.
  risk_class: reversible-write
  inputs:
    user_request: text
    repository: current-worktree
  outputs:
    patch: git-diff
    report: verification-summary
  model_policy:
    class: coding-reasoning
    fallback: none-without-disclosure
  non_goals:
    - deploy software
    - push protected branches
    - modify cloud infrastructure
    - access unrelated user files
  invocation:
    modes: [interactive]
  architecture:
    type: manager-specialists
    primary: engineer
    agents:
      engineer:
        role: implementation coordinator
      explorer:
        role: read-only architecture exploration
      reviewer:
        role: independent post-change review
  tools:
    - id: repository-read
      effects: [filesystem-read]
      risk: read-only
    - id: repository-write
      effects: [filesystem-write]
      risk: reversible-write
    - id: shell
      effects: [process-execution]
      risk: reversible-write
  policies:
    - prefer-small-diffs
    - inspect-before-edit
  permissions:
    default: ask
    allow:
      - repository-read
      - repository-write:path=${WORKTREE}/**
      - shell:git-status
      - shell:git-diff
      - shell:project-test
      - shell:project-lint
    deny:
      - filesystem:${HOME}/.ssh/**
      - filesystem:${HOME}/.aws/**
      - shell:sudo
      - shell:rm-rf
      - git:push-force
    ask:
      - network:any-unlisted
      - git:push
  sandbox:
    filesystem:
      writable: ["${WORKTREE}/**"]
    network:
      default: deny
  verification:
    required_before_success: true
    steps: [project-format, project-lint, affected-tests, diff-review]
  approvals:
    - action: git-push
      required: always
  budgets:
    max_tool_calls: 100
    max_fix_cycles: 3
    wall_clock_minutes: 30
  failure:
    authorization_error: fail-closed
    test_failure: retry-within-budget
    budget_exhausted: partial-result
  observability:
    tracing: true
    tool_events: true
    policy_decisions: true
    sensitive_content: false
  evals:
    trigger: true
    trajectory: true
    outcome: true
    adversarial: true
```
