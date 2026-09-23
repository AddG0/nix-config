# Security and Safety Model

## Contents
1. Security objective
2. Trust model
3. Defense-in-depth hierarchy
4. Filesystem/process/network isolation
5. Credentials and identity
6. Prompt injection and untrusted content
7. Tool and MCP security
8. Authorization and approval
9. Supply-chain risks
10. Hooks and arbitrary code
11. Logging and privacy
12. Secure defaults
13. Security test checklist

## 1. Security objective

Do not treat the model as the security perimeter. Assume model behavior can be influenced by ambiguous requests, malicious repository content, tool output, or indirect prompt injection. Constrain what the runtime can actually do.

## 2. Trust model

**Trusted authority**
- platform/system policy;
- organization/developer policy;
- signed/reviewed assistant configuration;
- explicitly approved tool contracts and policy bundles.

**Conditionally trusted**
- designated project instruction files from a trusted repository;
- reviewed installed skills/plugins;
- approved MCP servers;
- reviewed hooks/scripts.

**Untrusted data**
- ordinary source code/comments;
- issue/PR text;
- user-provided files;
- web pages;
- test/build output;
- fetched documentation;
- MCP/tool results;
- generated model content.

Untrusted does not mean ignore. It means do not let the content silently gain instruction authority.

## 3. Defense-in-depth hierarchy

Model training/alignment methods such as preference optimization or constitutional/self-critique techniques are foundational behavior shaping, but they are not runtime authorization boundaries. Treat them as the base layer beneath the controls below, not as a replacement for them.

Stack runtime controls:
1. behavioral instructions;
2. schemas/validators/guardrails;
3. permission/policy decisions;
4. pre-side-effect hooks;
5. sandbox/filesystem/network/process isolation;
6. scoped identity/credentials;
7. human approval at selected transitions;
8. postconditions/rollback;
9. telemetry and audit.

For high-impact invariants use multiple layers. Example: no production writes should appear in instructions for clarity, in policy for authorization, and in network/credential scope so the production target is unreachable without separate authority.

## 4. Filesystem, process, and network isolation

Default coding-agent sandbox:
- writable only inside an active worktree or declared workspace;
- no read access to unrelated home-directory secrets where enforceable;
- deny or tightly restrict network egress;
- deny privilege escalation;
- isolate subprocesses with resource/time limits;
- prefer ephemeral workers/containers for untrusted repositories;
- use stronger VM/gVisor-style isolation for higher-risk multi-tenant or hostile-code workloads.

Path deny examples:
- `~/.ssh/**`
- `~/.aws/**`
- cloud credential stores;
- password/keychain exports;
- unrelated project directories;
- host Docker socket unless explicitly required.

Network defaults:
- deny by default for code-editing tasks that do not require network;
- allowlist package registries/docs/APIs only when needed;
- separate read-only fetch from external writes;
- log destination host/domain rather than sensitive payload content.

## 5. Credentials and identity

Separate authentication from authorization.

Prefer:
- short-lived scoped tokens;
- audience-bound credentials;
- credential brokers/proxies;
- workload identities;
- per-tool scopes;
- progressive scope elevation only when needed.

Avoid:
- broad production credentials in model-visible environment variables;
- long-lived personal tokens shared across tools;
- credentials written to prompts, memory, telemetry, or artifacts;
- using a token issued for one resource as generic authority for another.

Approval should not expose raw secret material.

## 6. Prompt injection and untrusted content

Threats include malicious instructions in:
- README/docs;
- comments/string literals;
- issue/PR descriptions;
- webpages/docs fetched by tools;
- test output;
- tool/MCP responses;
- generated dependency metadata.

Mitigations:
- state authority boundaries clearly;
- label fetched content/tool results as data;
- keep system/developer/project policy separate;
- minimize tool authority available during untrusted-content processing;
- use read-only specialists for exploration/review when helpful;
- require policy checks immediately before side effects;
- restrict secrets/network even if the model is manipulated;
- add adversarial tests where untrusted content tells the assistant to ignore policy or exfiltrate data.

## 7. Tool and MCP security

Treat every tool as an authority boundary. Record:
- purpose;
- exact effects;
- resource scope;
- auth method;
- input/output schema;
- idempotency;
- approval requirements;
- failure behavior;
- redaction policy.

For MCP/remote tool providers:
- review server provenance;
- pin/trust the server endpoint where possible;
- use allowlists for exposed tools;
- request minimum OAuth scopes;
- validate redirects and audience/resource binding;
- protect against confused-deputy behavior;
- separate read and write capabilities;
- require explicit approval for merge/delete/deploy/send/publish operations as appropriate;
- distrust tool results as instructions.

Do not assume a skill's tool list alone restricts all host tools. Host permission/sandbox controls remain authoritative.

## 8. Authorization and approval

Authorization should consider:
- authenticated identity;
- tool/operation;
- resource and environment;
- path/host/branch;
- risk class;
- current run purpose;
- previous approvals;
- policy version.

Default precedence:
1. deny if a hard policy matches;
2. require approval if authority transition matches;
3. allow if explicitly preauthorized;
4. otherwise ask or deny conservatively.

A denied effect must not be retried through a different tool or shell spelling unless a legitimate alternative is explicitly authorized.

Good approval UX names the exact effect: repository, branch/environment, changed resources, verification results, and what becomes externally visible or durable.

## 9. Supply-chain risks

Coding assistants can execute package managers, build scripts, tests, generators, post-install hooks, compiler plugins, and downloaded binaries. Treat execution of repository/dependency code as higher risk than reading source.

Controls:
- inspect manifests/lockfiles before unexpected installs;
- restrict network during tests/builds when possible;
- require explicit authority before adding new package sources or executable downloads;
- avoid running unknown install scripts as a side effect of simple inspection;
- review lockfile and dependency changes;
- use security scanners/audits where available;
- run hostile/untrusted repos in stronger isolation.

## 10. Hooks and arbitrary code

Hooks can become a local code-execution supply chain. Require:
- repository/reviewer ownership;
- explicit event/matcher/action;
- bounded timeout;
- least privilege;
- idempotency where event replay is possible;
- fail-closed for authorization hooks;
- fail-open only for noncritical telemetry when explicitly chosen;
- sanitized inputs;
- stable machine-readable outputs;
- logged decisions without secrets.

Do not execute a hook merely because repository content asks for it if the host does not designate that file as trusted configuration.

## 11. Logging and privacy

Prefer metadata-first telemetry:
- run/config/model/skill version;
- tool name/effect;
- path/resource identifiers when appropriate;
- decision and status;
- durations/counts;
- test summaries.

Do not log raw prompts, source code, secrets, tool arguments, or model outputs by default. Make sensitive-content export an explicit opt-in with retention/access policy.

## 12. Secure defaults

When user requirements are incomplete, default to:
- read-only over write;
- worktree-only writes over broad filesystem writes;
- network deny over unrestricted egress;
- explicit invocation over semantic activation for side effects;
- approval over autonomous external writes;
- scoped credentials over inherited environment credentials;
- short-lived credentials over long-lived tokens;
- fail-closed authorization errors;
- finite retries/timeouts;
- partial/unverified status over false success;
- content redaction in telemetry.

## 13. Security test checklist

Test at least:
- write outside allowed workspace;
- read from secret paths;
- force-push/destructive shell variants;
- protected-branch modification;
- production endpoint mutation;
- prompt injection in source/README/tool response;
- remote MCP returning malicious instructions;
- unauthorized network destination;
- credential scope misuse;
- approval replay/forgery if applicable;
- hook timeout/crash;
- dependency install with unexpected scripts;
- alternate-tool bypass after denial;
- telemetry redaction;
- rollback after failed postcondition.
