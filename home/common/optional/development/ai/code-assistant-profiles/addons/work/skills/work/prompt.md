---
name: work
description: "Routes a piece of work to the skill or flow that fits it, and says where to clear context."
argument-hint: "[what you're about to do]"
---

# Work router

Situation: $ARGUMENTS

Pick the one row below that fits, name the skill to run next, and stop. Do not start the work. If two rows fit, say which comes first. If none fit, say so — don't force a match.

Ask at most one question, and only when the situation genuinely matches two rows that lead to different skills.

## Flows

| Situation | Run | Then |
|---|---|---|
| Idea or feature with fuzzy requirements | `/interview` | `/adr` for each hard-to-reverse decision |
| Plan or decision to stress-test | `/grilling` | `/adr` if a decision settles |
| Choosing between named options | `/decision-matrix` | `/adr` to record the pick |
| Picking up a Jira ticket | `/investigate` | implement, then `/review-branch` |
| New repo needs product/tech context docs | `/steering-setup` | — |
| Nix build or flake output failing | `/nix-build` | — |
| Program crashed (core dump) | `/diagnose-crash` | — |
| Bug, regression, or something slow | `/diagnosing-bugs` | `/review-local-changes` |
| Merge or rebase stopped on conflicts | `/resolving-merge-conflicts` | — |
| Tests failing | `/fix-tests` | — |
| Need a dev shell for a repo | `/dev-flake` | — |
| Long-running server, watcher, or log tail | `/tmux-dev` | — |
| Diagram of a system or flow | `/archify` | — |
| Threat model / security design | `/security-threat-model` | — |
| Changing assistant config, skills, rules, hooks | `/code-assistant-configurator` | `just eval-skills` |
| Uncommitted changes to check | `/review-local-changes` | `/commit` |
| Branch ready for review | `/review-branch` | `/commit`, push |
| GitHub PR to review | `/review-pr` | — |
| Release notes | `/changelog-generator` | — |
| Stale local branches | `/clean_gone` | — |
| Session ending or context is full | `/handoff` | start fresh with the handoff file |

## Phase boundaries

When moving to the next row, check in this order and take the first that applies:

1. Same task, context still small — continue.
2. New ticket or unrelated task — `/clear`.
3. Same task, context heavy, next step needs little of it — `/handoff`, then a fresh session.
4. A self-contained investigation — delegate to a subagent instead of doing it inline.
5. None of the above — `/compact`.
