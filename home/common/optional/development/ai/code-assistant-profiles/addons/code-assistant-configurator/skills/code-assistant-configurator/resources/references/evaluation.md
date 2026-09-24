# Evaluation, Verification, and Operations

## Contents
1. Evaluation philosophy
2. Test layers
3. Trigger evaluation
4. Trajectory evaluation
5. Outcome evaluation
6. Security evaluation
7. Failure and chaos testing
8. Performance and cost
9. A/B and regression testing
10. Telemetry model
11. Completion evidence

## 1. Evaluation philosophy

Evaluate the entire harness: model + instructions + skills + tools + policy + sandbox + state + hooks + approvals + verification. A better model cannot compensate for a broken permission boundary, and a correct final file does not excuse an unsafe trajectory.

Separate:
- task outcome quality;
- action trajectory quality;
- routing/trigger precision;
- security/authority correctness;
- operational performance.

## 2. Test layers

| Layer | Assertion example |
|---|---|
| Unit | dangerous shell classifier denies normalized destructive commands |
| Schema/contract | malformed tool request is rejected |
| Trigger | review prompt activates review capability |
| Negative trigger | implementation request does not activate reviewer |
| Integration | writes remain in worktree |
| Trajectory | verification occurs before success |
| Outcome | expected test passes / repository state is correct |
| Permission | external write always asks or denies per policy |
| Adversarial | malicious README cannot override authority policy |
| Failure/chaos | tool timeout yields bounded retry and partial result |
| Performance | latency/cost/tool-call budget remains within threshold |
| Regression | known task corpus does not materially degrade |

## 3. Trigger evaluation

For every skill/agent/command routing rule, build:
- obvious positive examples;
- paraphrased positives;
- boundary positives;
- obvious negatives;
- near-miss negatives;
- ambiguous cases that should ask rather than auto-trigger.

Measure:
- true positive rate / missed-trigger rate;
- false positive / over-trigger rate;
- routing latency/cost;
- conflict rate when multiple skills match.

Test explicit invocation separately from semantic activation.

## 4. Trajectory evaluation

Assert meaningful process properties, not chain-of-thought:
- repository inspected before editing when required;
- only allowed tools used;
- writes stayed in scope;
- no unauthorized network calls;
- tests/checks ran before success;
- approval occurred before external side effect;
- denial was not bypassed with an alternate tool;
- retry count stayed within budget;
- independent reviewer actually ran when policy required it.

Use tool traces, hook events, state transitions, and filesystem/Git evidence.

## 5. Outcome evaluation

Prefer executable or schema-based assertions:
- target tests pass;
- build succeeds;
- lint/typecheck pass;
- expected files/fields exist;
- forbidden files untouched;
- generated configuration validates;
- diff size/scope is plausible;
- no unrelated changes;
- deployment health check succeeds if deployment was authorized.

For subjective review, use a rubric with concrete evidence requirements rather than “looks good.”

## 6. Security evaluation

Include:
- prompt injection in repository/tool output;
- secret-path access;
- unauthorized host/network access;
- protected branch / production mutation;
- shell obfuscation variants;
- MCP tool overreach;
- credential audience/scope misuse;
- approval replay or forged client state;
- symlink/path traversal where relevant;
- malicious dependency/build scripts;
- telemetry leakage.

Test policy/hook/sandbox layers directly without a model too. A model refusing a dangerous action does not prove the control works.

## 7. Failure and chaos testing

Inject:
- test failures;
- missing binary/dependency;
- network timeout;
- MCP server error;
- hook crash/timeout;
- malformed tool result;
- partial write;
- merge conflict;
- context compaction/restart;
- approval rejection;
- budget exhaustion.

Expected behavior should distinguish retryable errors from hard policy failures and should stop after finite attempts.

## 8. Performance and cost

Track:
- end-to-end latency;
- model latency;
- tool latency;
- token/context size;
- tool-call count;
- subagent count;
- retry/fix cycles;
- cost where available;
- sandbox startup time;
- verification duration.

Do not introduce multi-agent orchestration or always-on hooks without measuring the overhead they add.

## 9. A/B and regression testing

When changing a mature configuration:
- maintain a representative task suite;
- compare new config against prior/baseline with same model/environment when possible;
- track task success, trigger precision, safety violations, cost, latency, and human intervention;
- require regression justification for any meaningful safety or quality decline.

Version configuration and eval suite together.

## 10. Telemetry model

Minimum useful signals:

| Signal | Examples |
|---|---|
| Identity | run/session/config/skill/policy/tool versions |
| Routing | selected skill, agent delegation, model policy |
| Model | latency, token use, stop reason, retries |
| Tool | name, normalized effect, duration, status |
| Permission | allow/ask/deny and policy reason |
| Hooks | event, handler, decision, latency, error |
| Files/resources | paths/resources touched, changed count |
| Verification | checks run, pass/fail, retry count |
| Human | approval requested/approved/rejected |
| Budgets | tool/turn/cost/time usage |
| Security | blocked secret/network/policy events |
| Outcome | complete/partial/failed/rolled-back |

Keep content logging separate and opt-in.

## 11. Completion evidence

A final assistant report should name:
- files/resources changed;
- commands/checks actually executed;
- pass/fail results;
- approvals used;
- anything unverified;
- limitations/assumptions;
- rollback/recovery status when relevant.

Do not claim a check ran if it did not. Do not use model confidence as a substitute for evidence.
