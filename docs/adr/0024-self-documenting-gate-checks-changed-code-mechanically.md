---
status: accepted
date: 2026-11-10
---

# The self-documenting rule is held by planning, a mechanical Stop check, and an advisory review at hand-off

## Context and Problem Statement

The `self-documenting` rule loads in every session, and the code still drifts from it. A 361-file audit of a Kotlin service written by agents with the rule loaded found 111 files (31%) failing its one-sentence test. Across two weeks of sessions on that service, the user asked "did we run the self-documenting / domain language review?" at least a dozen times.

How should the profile make the standard hold: as thinking done while the code is written, at a cost that suits every turn? The evidence is in `docs/work/self-documenting-gate/research.md`.

## Considered Options

1. **The prose rule alone.** This is what produced the audit.
2. **An independent reviewer subagent on every turn that changes code** (Sonnet, held by a Stop hook, passes recorded by blob hash). This was built first.
3. **A narrow yes/no reviewer on a cheap model, only when a turn changes structure.**
4. **A `type: "agent"` Stop hook.**
5. **PostToolUse reminders on `Write`/`Edit`.**
6. **A hook-enforced purpose declaration before each new file is written.**
7. **Per-repo linters only.**
8. **Planning up front, a mechanical Stop check on changed code, and an advisory judgment review at hand-off.**

## Decision Outcome

Chosen: option 8.

**Up front.** The rule asks Claude to settle the shape before writing. It lists each file the change creates or reshapes, with its one-sentence purpose and its names, and restructures the plan when a file has no sentence. This targets the half of the audit's failures that need judgment (names, placement, grab-bags) at the cheapest moment, and planning has modest evidence behind it.

**At every stop: a mechanical check.** The Stop hook (`addons/code-standards/self-documenting-gate/`) reads only what the session changed. It makes no model call.

What it reads:

- Each snapshot is every non-ignored file, tracked or not, written as a tree through a per-session copy of the index. The copy keeps the real index's mtime, so git's racy-clean check still holds, and the real index is never locked or rewritten.
- A `SessionStart` hook stores the session's first snapshot as its baseline, in the worktree's git dir. Work already uncommitted when the session began isn't counted.
- Code means an extension allowlist plus extensionless files starting with `#!`. Excluded: a top-level `docs/`, symlinks, submodule pointers, deletions, and content that matches the branch's remote upstream or a remote's default branch (a pull or checkout).

What it checks, on lines the session added and new files:

| Check | Severity | Why this severity |
| --- | --- | --- |
| A wholly new comment run with 3 or more lines of text (license headers and delimiter lines excluded) | fix: the turn is held | The comments rule caps a comment at one line, with no exceptions |
| A new file named `utils`, `helpers`, `misc` or `stuff` | fix | The rule names it outright |
| A function of 51 or more lines that overlaps new lines (ast-grep, ten languages) | look: one nudge | Long functions are a proxy for "not a story"; the audit passed some |
| A new top-level type name another file already declares | look | The same name across contexts can be deliberate |

- A fix finding blocks the turn. A look finding is passed to Claude as feedback once, and the turn goes on.
- A finding set already shown isn't shown again. If Claude stops again with a fix finding still there, the turn ends, and the user is told what was left unfixed.
- A turn paused on a background subagent or workflow isn't checked.
- `git config self-documenting.gate off` turns the check off for a repo.

**At hand-off: judgment, as advice.** The `self-documenting-reviewer` agent (Haiku) asks seven fixed yes/no questions per changed file, each one saying what passes. Its findings go to the user; nothing blocks on them.

### Consequences

- Good: no model call per turn. A stop with nothing changed costs about 50 ms. Checking a whole 361-file service as new code takes about 10 s.
- Good: the check is deterministic. It follows git state, so files written through Bash count, and the same code always gives the same findings.
- Bad: it covers only the mechanical third of the standard. Measured on the audit, it flags 64 files: 29 the audit failed and 26 it passed. Placement, grab-bags by content, and names that mean two things still depend on planning and the hand-off review.
- Bad: comment blocks are judged by line shape. A license header that doesn't say "copyright" or "license" would be flagged.
- Fail-open, on purpose: a hook that crashes exits non-zero, which Claude Code shows as a hook error before letting the turn end. Things that would otherwise switch the check off silently speak up instead:
  - a repo git refuses, or a snapshot git can't write, fails the hook with git's reason;
  - a lost or gc-pruned baseline restarts from now with a notice.
- Codex and opencode get the rule and the agent, but no hook. Codex has Stop hooks, but porting is a separate change.

### Why not the others

- **Option 1.** 31% of the audited files failed with the rule loaded. In 1,650 Claude Code sessions, the odds of following a CLAUDE.md instruction fell about 5.6% per function written.
- **Option 2.** It cost about 47k tokens per turn that touched code. Its judgment proved noisy too: validated on 20 audited files, a Sonnet reviewer matched the audit on 12 of 20 with plain questions. With sharper questions it matched 10 of 20, catching only 2 of the 10 failures; one change of wording flipped half its verdicts.
- **Option 3.** Haiku matched the audit on 11–12 of 20 files across the same two rounds, and agreed with Sonnet on only 14 of 20. A gate on that signal would either nag or miss, depending on wording.
- **Option 4.** It would run a model on every turn, since Stop takes no matcher or `if`. It is experimental, and has a 60-second default timeout.
- **Option 5.** No evidence that a static reminder works. It misses files written through Bash, and leaves the author grading their own work.
- **Option 6.** No study tests the gated form, and a declaration the author writes and grades is the weak link the self-review studies show. The plan step keeps the benefit without the gate.
- **Option 7.** Precise, but every language and repo differs, and linters can't apply the one-sentence test. They complement this.
