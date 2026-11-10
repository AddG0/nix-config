# How to hold AI-written code to the self-documenting standard, cheaply

2026-11-10. ADR 0024's gate puts an independent Sonnet reviewer on every turn that changes code, at about 47k tokens per run. That is expensive, and it comes after the code is written. The question here: which method gets the standard met while the code is written, and at what cost?

## Method

- **Three research passes**, run in parallel:
  - self-review, planning, adherence and in-loop feedback evidence;
  - how agent tools and teams enforce standards;
  - static coverage of each pattern, and how reliable LLM judges are.
- **Spot checks.** The two sources the recommendation leans on most (arXiv 2605.10039 and 2606.15689) were read at the source. The other sources are as the research passes reported them. Many are 2026 preprints, and are marked as such.
- **The audit split.** The 111 failures in a 361-file audit of an agent-written Kotlin service were classified by keyword. That service was written with the rule loaded.

Facts and judgment are kept apart. Everything under "Recommendation" is judgment.

## Findings

### 1. A rule in context fades as the session goes on

- In 1,650 Claude Code sessions (Sonnet 4.6), each additional function the agent wrote cut the odds of following a CLAUDE.md instruction by about 5.6% (OR 0.944). It replicated on a second codebase and on Opus 4.6. File size, instruction position and conflicting files had no detectable effect.
  - Caveat: the instruction was a trivial annotation.
  - Preprint, read at the source. [2605.10039](https://arxiv.org/abs/2605.10039)
- Code-style rules followed one at a time held at 96% (Claude 3.5 Sonnet). With six at once, all six held 1% of the time. Correctness was unaffected. EMNLP Findings 2025. [2509.21051](https://arxiv.org/abs/2509.21051)
- Models drift from their system prompt within 8 rounds of conversation. COLM 2024. [2402.10962](https://arxiv.org/abs/2402.10962)
- Anthropic's own docs:
  - CLAUDE.md is "context, not enforced configuration".
  - "If you keep adding emphasis to a CLAUDE.md line and Claude still misses it, that's a sign the line belongs in a hook."
  - Hooks are for rules with zero exceptions.
  - [best practices](https://code.claude.com/docs/en/best-practices), [memory](https://code.claude.com/docs/en/memory)

This matches the audit: the rule was loaded the whole time, and 31% of files failed.

### 2. Reviewing your own work, and the reviewer's limits

- Without outside feedback, self-correction made reasoning worse: GPT-3.5 on CommonSenseQA fell from 75.8 to 38.1. ICLR 2024. [2310.01798](https://arxiv.org/abs/2310.01798)
- In code repair, the quality of the feedback is the bottleneck. Human feedback raised GPT-4's repair rate 1.58×. GPT-4's own feedback was wrong in 32 of 80 cases. ICLR 2024. [2306.09896](https://arxiv.org/abs/2306.09896)
- Self-Refine did improve readability: meaningful variable names rose from 27% to 56%. The measure was narrow. NeurIPS 2023. [2303.17651](https://arxiv.org/abs/2303.17651)
- Diff size is "the dominant predictor of review quality". F1 was 0.657 on diffs under 10 lines and 0.043 on diffs over 150. Haiku 4.5 reviewed slightly better than Sonnet 4.6 (F1 0.365 vs 0.343) at 3.2× lower cost.
  - Caveat: this was bug-finding review.
  - Preprint, read at the source. [2606.15689](https://arxiv.org/abs/2606.15689)
- Anthropic warns: "A reviewer that's asked to find problems will always find something. If you fix every finding, you end up with extra abstraction layers." [best practices](https://code.claude.com/docs/en/best-practices)

### 3. Planning before writing helps a little

- Structured chain-of-thought (SCoT) made code that developers rated 15.9% better on maintainability, and raised pass@1 by up to 13.8%. TOSEM. [2305.06599](https://arxiv.org/abs/2305.06599)
- Self-planning raised pass@1 by up to 25% (relative), and raters judged its code the most readable. TOSEM 2024. [2303.06689](https://arxiv.org/abs/2303.06689)
- An architecture document plus a plan improved modularity, but only in three case studies of one system. [ICSE 2026 workshop](https://doi.org/10.1145/3786152.3788588)
- No study tests a per-file purpose declaration enforced by a gate.

### 4. Deterministic feedback while editing has the best record

- SWE-agent resolved 18.0% of SWE-bench Lite with a lint-checked edit, against 15.0% without the linter. The linter checked syntax only. NeurIPS 2024. [2405.15793](https://arxiv.org/abs/2405.15793)
- A Pylint feedback loop cut readability violations from over 80% to 11%. Most of the gain came by the third or fourth iteration. Preprint. [2508.14419](https://arxiv.org/abs/2508.14419)
- How teams that run agents at scale do it:
  - **OpenAI**, about 1M agent-written lines: replaced a giant AGENTS.md with a map of about 100 lines, plus custom linters and structural tests whose errors say how to fix them. [harness engineering](https://openai.com/index/harness-engineering/), via secondary summaries, since the page returned 403.
  - **Stripe**: local lint under 5 s before CI; CI capped at two rounds. [Minions](https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents)
  - **Aider**: lints every edited file by default and fixes what it finds. [docs](https://aider.chat/docs/usage/lint-test.html)
  - **Copilot's agent**: runs CodeQL and lint, then LLM review. [changelog](https://github.blog/changelog/2025-10-28-copilot-coding-agent-now-automatically-validates-code-security-and-quality/)
  - **Böckeler (Thoughtworks)**: deterministic sensors are "cheap and fast enough to run on every change". LLM sensors are "slower and more expensive … not on every commit". [harness engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- **Spotify** had an LLM judge on diffs that vetoed about 25% of sessions. They later dropped it for false fails, relying on code and tests instead. [part 3](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3), [InfoQ](https://www.infoq.com/presentations/spotify-ai-codebase-migration-agent/)
- No evidence found that a static reminder injected after a write works. What the reports back is specific validator output.

### 5. LLM judges: reliable only on narrow questions

- Open readability scores barely track humans: pooled Pearson 0.25 for Java and about 0 for Python, across 10 LLMs. A generic list of aspects didn't help. [CoReEval 2510.16579](https://arxiv.org/abs/2510.16579)
- Large judges reached Pearson 0.68–0.81 with humans on code tasks; 16–47B judges reached 0.28–0.46. ISSTA 2025. [2502.06193](https://arxiv.org/abs/2502.06193)
- Splitting criteria into yes/no questions raised agreement, most of all for small models. [CheckEval 2403.18771](https://arxiv.org/abs/2403.18771)
- Question-specific rubrics raised ICC from 0.56 to 0.82 on code grading. [2503.23989](https://arxiv.org/abs/2503.23989)
- For code smells: GPT-4 scored F1 0.95 on Large Class but 0.00 on Feature Envy. Putting metrics in the prompt raised God Class F1 from 0.69 to 1.0. [ACM](https://dl.acm.org/doi/full/10.1145/3756681.3756993), [SBES](https://sol.sbc.org.br/index.php/sbes/article/download/37005/36790/)
- Cheaper patterns that are documented:
  - judge the diff plus the prompt only (Spotify);
  - use Haiku for simple subagents (Anthropic);
  - review once per PR, not per push (Anthropic Code Review);
  - start with a cheap judge and escalate on disagreement ([Trust or Escalate 2407.18370](https://arxiv.org/abs/2407.18370)).

### 6. What static analysis can check

| Pattern | Static check | Examples |
| --- | --- | --- |
| Dead code | Yes | detekt UnusedPrivate*, knip, ruff F401/F841, staticcheck U1000, deadnix, shellcheck SC2034 |
| Flag argument | Yes, except Kotlin | ruff FBT001–003, revive flag-parameter, Sonar S2301, clippy `fn_params_excessive_bools` (max 0); ast-grep per grammar |
| File named for one declaration hiding others | Partly | detekt MatchingDeclarationName, Checkstyle OneTopLevelClass, ESLint max-classes-per-file; ast-grep plus a script comparing declarations with the file name |
| One name, two meanings | Same-name collisions only | No built-in rule. ctags or ast-grep output grouped by name; custom ArchUnit rule |
| Copied helpers | Yes | CPD, jscpd |
| Comment runs | Yes | the existing `comment-block` hook |
| Sentinel return / assembled contract | Partly | Go nilnil, clippy `result_unit_err`, typescript-eslint no-explicit-any, `disallowed_types` |
| Placement / grouping by kind | Only for layer rules a repo declares | ArchUnit, Konsist, dependency-cruiser, import-linter; revive's bad package names |
| Entry point as a story; "unrelated" concerns | No | Length and complexity proxies only (LongMethod, max-statements) |

**Tooling:** ast-grep covers all seven languages in use here (Kotlin, TypeScript, Nix, Bash, Python, Go, Rust) and runs per file, fast enough for a hook. Semgrep has no Nix support and costs 2–3 s per call. [ast-grep languages](https://ast-grep.github.io/reference/languages.html)

### 7. The audit, split

This is a keyword classification of the reason given for each of the 111 failing files, so it is approximate:

- **32 (29%)** failed only on patterns a linter can flag: dead code, copied code, comment runs, a file named for one declaration, name collisions.
- **58 (52%)** failed on at least one pattern that needs judgment. By pattern: unclear or overloaded name 22, grab-bag 15, misplaced 15, entry point not a story 9, contract or sentinel 5.
- **21** didn't match a keyword.

### 8. Validation: Haiku and Sonnet against the audit

Twenty files from the audited service at the audited commit: ten the audit failed on judgment-only patterns (grab-bag, misplaced, entry point not a story, flag or sentinel, unclear name), and ten it passed. Haiku and Sonnet each got the same yes/no questionnaire, ran blind to the audit, and read the files with `git show`. A file failed when any answer flagged a problem.

| Round | Model | Matches audit | Failures caught | Passes wrongly failed | Tokens | Time |
| --- | --- | --- | --- | --- | --- | --- |
| 1: plain questions | Haiku 4.5 | 11/20 | 9/10 | 8/10 | 165k | 240 s |
| 1 | Sonnet | 12/20 | 8/10 | 6/10 | 108k | 104 s |
| 2: each question states what passes, "answer the passing way unless you can point at the line" | Haiku 4.5 | 12/20 | 6/10 | 4/10 | 155k | 243 s |
| 2 | Sonnet | 10/20 | 2/10 | 2/10 | 114k | 146 s |

- **Round 1's wrong fails clustered.**
  - A concept's own result and change types in its file were read as "hiding" declarations: the rule's own wording ("hides no others") and its `Order.kt` example said so.
  - A nullable meaning "not found" was read as a sentinel.
  - Code doing its own layer's job (an adapter's queries) was read as misplaced.
- **Round 2 fixed those three clusters, and swung Sonnet from strict to lenient.** Rewording changed half its verdicts.
- **Between the models**, round-2 verdicts agree on 14/20.
- **The only judgment both models made consistently was "long public function"** (the same 3 files in round 2). That is measurable without a model.
- **The ground truth is itself one LLM pass,** so 60% agreement says the standard's judgment half is noisy to judge, not that either model is wrong.
- **Cost:** Haiku used more tokens and time than Sonnet. At a third of the per-token price, it came to about half Sonnet's cost here.

**What it changes.** A model-judged gate on this standard would either nag or miss, depending on wording, whichever model runs it. That fits the readability-judge evidence (section 5) and Spotify dropping its judge. It drops recommendation step 3 below: the narrow model check per structural change. Judgment moves to planning (step 1) and to an advisory review at hand-off (step 4). The gate becomes deterministic only.

### 9. The deterministic checks, measured on the audited service

The gate's checks were run with the whole service treated as new code (361 files, about 10 s; a normal turn's few files take well under a second). Each check's flags were then compared with the audit's verdicts. The audit's base rate is 31% failing.

| Check | Severity | Files flagged | Audit failed | Audit passed | Not in audit |
| --- | --- | --- | --- | --- | --- |
| Comment block (≥3 lines of text, wholly new, not a license header) | fix | 26 | 12 | 10 | 4 |
| Long function (≥51 lines, overlapping new lines) | look | 6 | 4 | 2 | 0 |
| Type name another file declares (aliases, docs and shell excluded) | look | 40 | 14 | 17 | 9 |
| Grab-bag file name (new files only) | fix | 0 | – | – | – |

- **First run: 456 comment findings.** 364 of them were the repo's mandated 6-line copyright header, and most of the rest were short KDocs whose `/**` and `*/` lines were counted as text. Skipping license headers and counting only lines with text brought it to 27 findings.
- **Speed:** a `git grep` per declared type cost 70 s; one declaration index for the whole tree cut it to about 10 s.
- **A bug hunt on the rebuilt gate** found these, each now fixed with a regression test:
  - findings came out in ast-grep's thread order, so "already shown" never matched and a turn could be held on every stop;
  - pushing the session's own work exempted it as "upstream";
  - `sort | head` died of SIGPIPE on a type name declared in hundreds of files;
  - C preprocessor lines and Python operator continuations counted as comments;
  - porcelain `git diff` was hidden by external diff tools, and treated `[id].tsx` as a glob.

  Fixing aliases and self-matches cut name-collision flags from 66 files to 40.
- **The audit's misses.** Some "audit passed" hits still break the rules as written. A five-line doc comment breaks "cap at one line". Several same-name copies across contexts were later merged under the user's "one concept, one type" decision. So comments stay a fix, and the other two stay nudges.

## Recommendation (judgment)

No study tests the three designs against a structural standard, so this is built from the evidence above.

1. **Plan the structure before writing it.** When a change creates or reshapes files, the plan names each file and its one-sentence purpose before any code is written. The domain-language-steward skill's design-vocabulary mode settles the names. This is the up-front thinking. It costs a few lines of plan, and it targets the judgment half (names, placement, grab-bags). Planning has modest but real evidence behind it, and Anthropic recommends it. It shouldn't be a hook-enforced gate: nothing supports that form, and a declaration the author grades is the weak link the self-review studies show.
2. **Deterministic checks at write time, every edit, in milliseconds.** An ast-grep ruleset shipped with the profile covers the lintable patterns in every language here: flag arguments, a file named for one declaration that holds others, same-name collisions, grab-bag names. Each finding comes with a fix instruction, as `comment-block` already does. Each repo's own linters get the rules from the table, set up through `dev-flake`, and the hook runs them when present. This is the method with the best evidence, and it covers about 30% of the audited failures at no model cost.
3. **~~A narrow judgment check, only on structural change.~~ Dropped after validation (section 8).** It runs only when a turn created or moved a file, or added a top-level declaration, not on every edit.
   - The check is three or four yes/no questions about that file and its diff: "Does every top-level declaration serve this file's one-sentence purpose?", "Is any name already used for something else?", "Does the entry point read as named steps?"
   - Narrow questions over a small diff are where small models hold up, so Haiku fits.
   - This replaces the open-ended Sonnet review on every turn.
4. **One independent review at hand-off, split per file.** This is P1 in the friction plan. Reviewer accuracy collapses on large diffs, so the review has to be split per file, as `review-branch` already splits work across agents.
5. **Let reviewers pass.** Fail only on a named pattern, so findings don't pile on abstraction. The current agent already does this.

### Against what ADR 0024 built

- **Keep:**
  - the snapshot and baseline mechanics;
  - pass records keyed by content hash;
  - the Stop hook as the place that collects what a turn changed;
  - the loop guard;
  - the agent's JSON contract.
- **Change:**
  - what triggers a model call: structural changes only;
  - what the model is asked: yes/no questions, not open review;
  - which model: Haiku;
  - what runs first: deterministic checks.
- **Add:** the plan-first step in the rule, and the ast-grep ruleset.
- **Rough cost:**
  - turns that only edit inside existing declarations cost milliseconds;
  - structural turns cost one Haiku pass over a small diff, roughly an order of magnitude below a Sonnet review of every changed file;
  - the hand-off review runs once per branch.

## Open questions

- Does Haiku answer the yes/no questions as well as Sonnet does on the audit's failing files? Measure it before switching: replay ten failing and ten passing files through both.
- How much do the ast-grep rules for "file named for one declaration" and "same-name collisions" catch in practice, and how noisy are they? Run them over the audited service.
- How should "a top-level declaration was added" be detected per language? An ast-grep query is the likely answer; a regex is the fallback.
