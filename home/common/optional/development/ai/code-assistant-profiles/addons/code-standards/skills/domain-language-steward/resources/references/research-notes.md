# Research Notes and Design Rationale

Consulted on 2026-08-29. This file records provenance for maintaining the skill; it is not required during ordinary code reviews.

## Contents

- [Video basis](#video-basis)
- [Empirical identifier-naming research](#empirical-identifier-naming-research)
- [Domain language and context](#domain-language-and-context)
- [Modularization and refactoring](#modularization-and-refactoring)
- [Comment purposes and taxonomy](#comment-purposes-and-taxonomy)
- [Comment drift and contradictory claims](#comment-drift-and-contradictory-claims)
- [Selective AI-generated comments](#selective-ai-generated-comments)
- [Language and repository documentation guidance](#language-and-repository-documentation-guidance)
- [Documentation placement](#documentation-placement)
- [Semantic surfaces and observability](#semantic-surfaces-and-observability)
- [Prompting-guide review](#prompting-guide-review)
- [Resulting prompt architecture](#resulting-prompt-architecture)

## Video basis

Requested video:

- Kevlin Henney, “Giving code a good name” — https://www.youtube.com/watch?v=CzJ94TMPcD8
- Public talk synopsis mirror — https://golangnews.com/stories/4331-video-giving-code-a-good-name-kevlin-henney
- Speaker’s slide collection, including the 72-slide deck — https://www.slideshare.net/Kevlin

The browsing environment did not expose the complete video transcript. The skill therefore uses the published synopsis, available slide metadata, and Henney’s related writing rather than claiming a timestamp-by-timestamp transcription.

Recurring ideas applied by the skill:

- Treat names as communication, not labels.
- Use names to shape the reader’s mental model and reveal intentional structure.
- Avoid affix-heavy conventions that dilute meaning.
- Treat naming as design work rather than a cosmetic final pass.

Related writing:

- Kevlin Henney, “Exceptional Naming” — https://kevlinhenney.medium.com/exceptional-naming-6e3c8f5bffac

This informed the rules against mechanically adding prefixes and suffixes, repeating type information, and treating a consistently noisy convention as inherently valuable.

## Empirical identifier-naming research

- Dror G. Feitelson et al., “How Developers Choose Names” — https://arxiv.org/abs/2103.07487
- Rachel Alpern et al., “Reproducing, Extending, and Analyzing Naming Experiments” — https://arxiv.org/abs/2402.10022

The original study describes naming as three conceptually distinct choices:

1. Select concepts to communicate.
2. Choose words for those concepts.
3. Construct the identifier.

It found low agreement on exact names and reported that explicitly applying this model produced names judged better at roughly a two-to-one ratio. The later replication reinforces the importance of concept selection while cautioning that merely requesting longer identifiers does not reproduce the benefit.

This is why the skill performs concept selection before word choice and does not enforce either short or long names as a universal rule.

## Domain language and context

- Martin Fowler, “Ubiquitous Language” — https://martinfowler.com/bliki/UbiquitousLanguage.html
- Martin Fowler, “Bounded Context” — https://martinfowler.com/bliki/BoundedContext.html

These sources informed the rules to:

- Ground shared vocabulary in the domain model.
- Test vocabulary in conversation, code, tests, and documentation.
- Allow language and models to evolve as understanding improves.
- Require consistency inside a bounded context rather than forcing one global model.
- Make mappings explicit where shared words have different meanings across contexts or audiences.

The semantic-surface audit extends this idea beyond identifiers. Code, tests, APIs, events, errors, UI labels, and telemetry all teach users what the model is, but they do not always need identical words when an explicit audience or boundary translation is more accurate.

## Modularization and refactoring

- David L. Parnas, “On the Criteria to Be Used in Decomposing Systems into Modules” — https://doi.org/10.1145/361598.361623
- Martin Fowler, Refactoring catalog — https://refactoring.com/catalog/index.html
- Change Function Declaration — https://refactoring.com/catalog/changeFunctionDeclaration.html
- Extract Function — https://refactoring.com/catalog/extractFunction.html
- Move Function — https://refactoring.com/catalog/moveFunction.html

Parnas’s work informed the structural rules. Move and split based on what a module hides, owns, protects, or permits to vary—not merely execution order, line count, or file size.

The skill uses established refactoring terms but adds semantic evidence gates. The existence of a named refactoring does not make it appropriate. It also includes LEAVE, MERGE / INLINE, and DEFER so an assistant is not rewarded only for proposing more abstraction.

## Comment purposes and taxonomy

Primary source:

- Luca Pascarella, Magiel Bruntink, and Alberto Bacchelli, “Classifying code comments in Java software systems,” Empirical Software Engineering 24 (2019) — https://doi.org/10.1007/s10664-019-09694-w

The study analyzed comments from six open-source and eight industrial Java projects, manually classifying more than 40,000 lines. It produced six top-level categories and sixteen subcategories. Important distinctions include:

- **Purpose**: summary/what, expansion/how, and rationale/why
- **Notice**: deprecation, usage, and exception information
- **Under development**: TODO, incomplete prose, and commented-out code
- **Style and IDE**: directives and formatters
- **Metadata**: license, ownership, and pointers
- **Discarded**: automatically generated or unknown material

The taxonomy is evidence against the simplistic rule that every useful comment must explain only “why.” Comments serve different audiences and purposes. A protocol layout, public capability summary, usage example, exception condition, or tool directive should be judged by its own job.

The paper also shows why raw comment-count or comment-ratio targets are weak quality measures: different categories contribute very differently to comprehension and maintenance.

Applied design choices:

- Classify a comment’s job before judging it.
- Treat generated, directive, and legal comments separately from explanatory prose.
- Avoid blanket removal of summaries or “how” comments.
- Avoid blanket comment-generation quotas.

## Comment drift and contradictory claims

Sources:

- Lin Tan, Ding Yuan, Gopal Krishna, and Yuanyuan Zhou, “iComment: Bugs or Bad Comments?” SOSP 2007 — https://doi.org/10.1145/1294261.1294276
- Beat Fluri, Michael Würsch, and Harald C. Gall, “Do Code and Comments Co-Evolve?” WCRE 2007 — https://doi.org/10.1109/WCRE.2007.21
- Sheena Panthaplackel et al., “Deep Just-In-Time Inconsistency Detection Between Comments and Source Code,” AAAI 2021 — https://doi.org/10.1609/aaai.v35i1.16119

The central lesson from inconsistency research is that a code/comment contradiction has two plausible directions: the code can violate a correct stated rule, or the comment can be stale or wrong. An assistant should therefore investigate the intended contract rather than automatically making prose match executable behavior.

Fluri and colleagues found that comment changes were usually committed in the same revision as associated source changes in the three systems they studied, while also finding that newly added code was sparsely commented. The skill uses the practical implication rather than generalizing the exact percentages to all repositories: review related explanations in the same semantic change and validate them before completion.

Applied design choices:

- Treat comments and docs as claims, not authority.
- Flag contradictions as possible correctness issues.
- Use DEFER when the authoritative behavior cannot be established.
- Re-search comments, examples, docs, and operational material after a rename or move.
- Never “repair” rationale by inventing a plausible history.

## Selective AI-generated comments

- Skyler Grandel et al., “COMCAT: Leveraging Human Judgment to Improve Automatic Documentation and Summarization” — https://arxiv.org/abs/2407.13648

COMCAT separates three decisions: where a comment would help, what type of comment belongs there, and what the comment should say. Its human-subject evaluation reported comprehension improvements of up to 12% for 87% of participants and preference over standard ChatGPT-generated comments for up to 92% of evaluated snippets.

The result is not evidence that every code block needs a generated comment. It supports selective, purpose-aware generation grounded in a specific comprehension gap.

Applied design choices:

- Identify a concrete gap before generating prose.
- Select location and comment purpose before wording.
- Prefer no comment over fabricated rationale.
- Include negative examples that reject line-by-line paraphrasing.
- Evaluate generated comments for accuracy, usefulness, placement, and drift risk.

## Language and repository documentation guidance

### Google style guides

- Google Java Style Guide — https://google.github.io/styleguide/javaguide.html
- Google Python Style Guide — https://google.github.io/styleguide/pyguide.html
- Google C++ Style Guide — https://google.github.io/styleguide/cppguide.html

The current Java and Python guides define TODOs as temporary or short-term work and recommend a searchable format with a contextual resource, preferably a tracked bug. They also require a specific date or event when removal is deferred to the future. The exact syntax differs among repositories, so the skill preserves local convention while requiring concrete context and an exit condition.

Applied design choices:

- Reject `TODO: clean this up later` as insufficient.
- Link only real issues or resources; never fabricate identifiers.
- Name a version, migration, date, or event instead of using unanchored terms such as “soon” or “temporary.”
- Keep TODO/FIXME semantics repository-specific.

### Go documentation

- “Go Doc Comments” — https://go.dev/doc/comment

Go treats doc comments as tool-consumed API documentation and expects every exported name to have one. Its guidance focuses function documentation on what callers need, including special cases and observable guarantees, while leaving replaceable implementation details inside the function.

Applied design choice: do not delete brief public docs merely because another ecosystem might consider them redundant. Respect the language’s documentation contract without adding filler.

### Rust documentation and executable examples

- “How to write documentation,” The rustdoc book — https://doc.rust-lang.org/rustdoc/how-to-write-documentation.html
- “Documentation tests,” The rustdoc book — https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html

Rust’s guidance recommends concise summaries, relevant sections such as Panics, and examples. It notes that restating types already visible in the signature adds little value. Rustdoc can extract and execute examples as tests, helping keep them current.

Applied design choices:

- Document caller-relevant edge cases and failure behavior.
- Avoid signature paraphrase as filler.
- Prefer doctests or compile-checked examples when supported.
- Run documentation tests as part of a semantic refactor.

### Linux kernel guidance

- Linux kernel coding style — https://docs.kernel.org/process/coding-style.html

The kernel guide warns against excessive comments and comments that merely restate obvious implementation, but its broader treatment does not justify a universal “why only” rule. The skill adopts the narrower principle: comment what is non-obvious and important, and choose code when code can communicate the same claim more reliably.

## Documentation placement

Sources:

- Diátaxis — https://diataxis.fr/
- Diátaxis compass — https://diataxis.fr/compass/
- AWS Prescriptive Guidance, architectural decision records — https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/introduction.html
- AWS ADR process — https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html

Diátaxis distinguishes four user needs and corresponding forms: tutorials, how-to guides, reference, and explanation. It informed the rule to place information according to audience and task rather than treating every explanation as an inline comment.

AWS’s ADR guidance recommends capturing the context, decision, and consequences of architecturally significant choices, including considered alternatives and status. It also describes superseding prior decisions instead of silently rewriting history.

Applied placement model:

- Keep a narrow implementation hazard beside the code.
- Put public guarantees in API documentation.
- Put shared concept definitions in a glossary.
- Put executable behavior in tests or doctests.
- Put architectural tradeoffs in ADRs.
- Put operational procedures in runbooks.
- Put tracked temporary work in issues plus concise local TODOs when location matters.
- Keep one authoritative source and use links or audience-specific summaries instead of duplicating essays.

## Semantic surfaces and observability

- OpenTelemetry, “Semantic Conventions” — https://opentelemetry.io/docs/concepts/semantic-conventions/

OpenTelemetry defines common names for operations and data across traces, metrics, logs, profiles, and resources. The broader design lesson is that observability has a vocabulary and contracts of its own. Names and attributes may be consumed by dashboards, alerts, parsers, saved queries, and incident procedures even when they are not customer APIs.

Applied design choices:

- Include errors, logs, metrics, traces, dashboards, alerts, and saved queries in semantic-surface audits.
- Prefer stable operation names and structured attributes over variable details embedded in names.
- Reuse ecosystem semantic conventions when they fit.
- Track units and aggregation semantics for metrics.
- Treat operational rename migrations as contract changes.
- Keep high-cardinality or sensitive values out of bounded metric dimensions and stable operation names.

The semantic-surface reference also includes tests, API/schema names, storage, configuration, events, UI text, and vendor representations. This was added because developers learn the domain model from all of these surfaces, not source identifiers alone.

## Prompting-guide review

### OpenAI

- Current model guidance — https://developers.openai.com/api/docs/guides/latest-model
- Prompt engineering — https://developers.openai.com/api/docs/guides/prompt-engineering

Current OpenAI guidance recommends lean prompts: state instructions once, expose only relevant tools, retain examples when they encode a requirement or correct a measured gap, and rerun representative evaluations when simplifying.

Applied guidance:

- Keep the main `SKILL.md` as a control plane rather than a knowledge dump.
- Move detailed guidance into references loaded only when relevant.
- Avoid repeating the same comment rules in several files.
- Retain examples and evaluation cases because they constrain known failure modes.

### Anthropic

- Prompt engineering overview — https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview
- Claude prompting best practices — https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Define success criteria — https://docs.anthropic.com/en/docs/test-and-evaluate/define-success

Applied guidance:

- Define success criteria and evaluations before tuning wording.
- Use clear, direct, sequential instructions.
- Include representative positive and negative examples.
- Make recommendation versus action explicit.
- Avoid aggressive language that would trigger automatic renaming, extraction, or comment generation.

### Google

- Prompt design strategies — https://ai.google.dev/gemini-api/docs/prompting-strategies

Google’s current guidance recommends precise, direct instructions; consistent structure; explicit definitions for ambiguous terms; context; and decomposition for complex workflows.

Applied guidance:

- Separate evidence gathering, diagnosis, decision, migration, and validation.
- Define the decision and disposition vocabularies explicitly.
- Use Markdown sections and compact output templates.
- Preserve a proportional path for small naming questions.

## Resulting prompt architecture

The combined research produced these design choices:

- A narrow trigger description covering naming, domain vocabulary, comments/documentation, semantic surfaces, and structural placement.
- A staged workflow: evidence, domain reading, concept/word/form naming, explanation review, diagnosis, design decision, ownership, semantic-surface audit, consequences, output, and validation.
- A fixed design vocabulary containing LEAVE, RENAME, INTRODUCE CONCEPT, EXTRACT, MOVE, SPLIT, MERGE / INLINE, and DEFER.
- A separate explanation vocabulary containing KEEP, ADD, REWRITE, REMOVE, RELOCATE, CONVERT, and DEFER.
- Explicit protection against invented rationale, history, issue IDs, guarantees, and constraints.
- An explanation-placement matrix spanning code, doc comments, module docs, glossaries, ADRs, tests/doctests, runbooks, issues, and version history.
- A semantic-surface audit spanning identifiers, tests, docs, APIs, schemas, storage, configuration, events, errors, UI vocabulary, and observability.
- Conservative default behavior: recommend unless implementation is explicitly requested.
- Positive and negative examples, including cases where a framework role, concise local name, rationale comment, protocol explanation, or audience-specific term should remain.
- A regression suite that evaluates explanation integrity in addition to naming, boundaries, evidence, proportionality, and actionability.
- Progressive loading so ordinary reviews do not consume the research notes or every specialized reference.
