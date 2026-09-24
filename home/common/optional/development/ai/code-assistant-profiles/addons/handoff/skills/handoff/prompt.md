---
name: handoff
description: "Writes a handoff document a fresh session can resume from without this conversation."
argument-hint: "[what the next session should focus on]"
---

# Handoff

Compress this session into a document another agent can resume from cold. It will not see this conversation — only the document and whatever it links to.

Focus for the next session: $ARGUMENTS

## Rules

- **Link, don't copy.** Point at the branch, commits, `docs/work/<topic>/`, ADRs, tickets, and file paths. Only write down what exists nowhere else: decisions made in chat, dead ends, and why.
- **Separate verified from believed.** Mark anything not checked by a command this session as unverified.
- **Redact secrets.** No tokens, keys, passwords, or private URLs with credentials.
- **Current state, not history.** The next agent needs where things stand, not the order they happened in.

## Gather first

1. `git status --short` and `git log --oneline -10` in each repo touched.
2. Uncommitted and staged changes: which are this session's and which were already there.
3. The last verification run (build, test, eval) and its result.

## Write

Write to `${TMPDIR:-/tmp}/handoff-<short-topic>-<YYYYMMDD-HHMM>.md`:

```markdown
# Handoff: <topic>

## Goal
<one or two sentences: what done looks like>

## State
- Done and verified: …
- Done, unverified: …
- In progress: … (file:line where it stops)
- Not started: …

## Decisions
- <decision> — <why>; rejected <alternative> because <reason>. (Link the ADR if one exists.)

## Dead ends
- <what was tried> — <why it failed>, so it isn't retried.

## Open questions
- <question> — <who or what can settle it>

## Artifacts
- Repo/branch: … · Commits: … · Docs: … · Ticket: …

## Next action
<the single first step, concrete enough to run>

## Suggested skills
<skills the next session should reach for, if any>
```

Then print the path and a command to resume: `claude "Read <path> and continue from Next action."`
