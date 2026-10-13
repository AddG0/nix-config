# Comments and Documentation

Use this reference when reviewing or generating comments, doc comments, TODO/FIXME notes, examples, architectural explanations, and other prose near code.

## Contents

- [Core principle](#core-principle)
- [Classify the job before judging the prose](#classify-the-job-before-judging-the-prose)
- [Explanation dispositions](#explanation-dispositions)
- [Review workflow](#review-workflow)
- [When an explanation earns its place](#when-an-explanation-earns-its-place)
- [When code should carry the meaning](#when-code-should-carry-the-meaning)
- [Choose the durable location](#choose-the-durable-location)
- [Public contract documentation](#public-contract-documentation)
- [TODO FIXME and temporary notes](#todo-fixme-and-temporary-notes)
- [Staleness and contradiction](#staleness-and-contradiction)
- [Generated directive and legal comments](#generated-directive-and-legal-comments)
- [AI-assisted comment generation](#ai-assisted-comment-generation)
- [Examples](#examples)

## Core principle

Treat every explanation as a claim that must earn its maintenance cost.

Use names, types, structure, APIs, and executable tests to express meaning they can state clearly and verify. Use prose for important rationale, constraints, interpretation, or operational knowledge that those mechanisms cannot express economically.

Do not enforce slogans such as “comments explain why, never what.” A useful explanation may summarize what a public abstraction provides, expand how a non-obvious algorithm or protocol works, state why a tradeoff exists, or warn about a hazard. Judge whether the information is necessary, accurate, and well placed.

Do not treat a confident comment as authority. Check it against behavior, tests, contracts, and current decisions. A contradiction can mean the prose is stale, the code is wrong, the test is wrong, or the intended contract is unresolved.

## Classify the job before judging the prose

Identify the explanation’s purpose:

| Purpose | Question it answers | Typical form |
|---|---|---|
| **Summary** | What capability or concept is this? | Public doc comment, module overview |
| **Expansion** | How does this non-obvious mechanism, format, or algorithm work? | Block comment, diagram, example |
| **Rationale** | Why was this choice made or simpler alternatives rejected? | Focused comment, ADR |
| **Contract / usage** | What may callers rely on and how should they use it? | API docs, examples, doctests |
| **Invariant / hazard** | What must remain true or what is unsafe to change casually? | Local comment, assertion, test, type |
| **Boundary / compatibility** | What external quirk, version, representation, or migration constraint applies? | Adapter comment, compatibility docs |
| **Work item** | What is incomplete, why is it deferred, and when can it be removed? | TODO/FIXME linked to tracked work |
| **Directive** | What must a compiler, linter, formatter, generator, or tool do? | Structured suppression or directive |
| **Generated / legal** | What provenance, license, or generation rule applies? | Header, generated marker |

The categories can overlap. A public doc comment may summarize a capability and specify its contract. Keep each explanation focused on the information its audience needs.

## Explanation dispositions

Choose one disposition for each explanation finding:

### KEEP

Keep the explanation when it is accurate, non-obvious, useful to its audience, and placed where future maintainers will find and update it.

Do not remove valuable rationale merely because nearby code now reads better. A name can describe the chosen behavior without preserving why another plausible behavior is forbidden.

### ADD

Add an explanation only when evidence establishes important information that code cannot carry economically. Good candidates include:

- An externally imposed compatibility constraint
- A surprising but intentional domain rule
- A security, concurrency, ordering, or performance tradeoff
- A public guarantee or failure mode not visible from the signature
- A mathematical derivation or protocol layout
- A temporary compatibility bridge with a known removal condition

Do not invent a reason to make code appear intentional.

### REWRITE

Rewrite when the information belongs here but is ambiguous, stale, overly broad, audience-inappropriate, or more certain than the evidence.

Prefer a compact factual statement over narrative history. State the constraint and consequence. Link to an authoritative source when details would otherwise be duplicated.

### REMOVE

Remove when the explanation:

- Narrates syntax or repeats an already clear name and type
- Describes behavior that no longer exists
- Contains no actionable or durable information
- Is commented-out code preserved instead of using version control
- Repeats nearby documentation without serving a distinct audience
- Contains vague blame, diary history, or unsupported speculation
- Suppresses a warning whose justification no longer applies

Before deleting, verify that no rationale, constraint, example, or migration knowledge would be lost.

### RELOCATE

Relocate when the claim is useful but the current location is not its durable owner. Leave a short local pointer only when readers need it to avoid a dangerous change.

Examples:

- Move system-wide tradeoffs to an ADR.
- Move operational recovery steps to a runbook.
- Move a domain definition to a glossary.
- Move reusable API guidance to public documentation.
- Move tracked future work to an issue and retain a concise linked TODO only when local visibility matters.

### CONVERT

Convert prose into a mechanism that keeps the claim verifiable:

- Rename a predicate instead of narrating its boolean expression.
- Introduce a value type to encode units or validity.
- Replace a prose invariant with construction-time validation plus a focused test.
- Turn an API example into a doctest or compile-checked example.
- Replace an ad hoc key/value convention with a schema or typed interface.
- Replace a long state-machine explanation with explicit states, transitions, and tests, while retaining rationale that types cannot encode.

Conversion does not imply deleting all prose. Preserve the portion that explains rationale or external constraints.

### DEFER

Defer when truth cannot be established safely. State exactly what evidence is missing, such as the authoritative contract, a domain-owner decision, historical incident, external consumer list, or vendor guarantee.

Do not “fix” an unexplained workaround by inventing a plausible story.

## Review workflow

For each material explanation:

1. **Identify the claim.** Rewrite it privately as a testable statement.
2. **Identify the audience.** Developer at the line, API consumer, operator, domain expert, or future decision maker.
3. **Classify the purpose.** Summary, expansion, rationale, contract, invariant, boundary note, work item, directive, or legal/generated text.
4. **Verify the claim.** Inspect implementation, tests, call sites, contracts, linked issues or ADRs, and external documentation when available.
5. **Check code expressibility.** Determine whether naming, typing, structure, assertions, schemas, or tests can carry the meaning more reliably.
6. **Choose a disposition.** KEEP, ADD, REWRITE, REMOVE, RELOCATE, CONVERT, or DEFER.
7. **Choose the owner.** Put the remaining information at the narrowest location where its audience will find it and its truth can be maintained.
8. **Check drift.** Search copies, examples, generated docs, old terms, and references that must change together.
9. **Validate.** Run documentation tools, doctests, link checks, linters, builds, and tests when available.

Review important comments around changed code even when the user asks only for a rename. A semantic refactor that leaves the old story in prose is incomplete.

## When an explanation earns its place

Prefer prose when it preserves information such as:

- **Rationale and tradeoffs**: Why a plausible alternative is incorrect, unsafe, or intentionally deferred
- **Domain exceptions**: A rule that surprises readers but is confirmed by the domain or contract
- **External constraints**: Vendor defects, protocol requirements, platform behavior, compatibility windows, or regulatory rules
- **Invariants and coupling**: Ordering, atomicity, idempotency, lifecycle, or ownership requirements not evident locally
- **Units and interpretation**: Whether a number is gross/net, inclusive/exclusive, UTC/local, wall-clock/monotonic, exact/estimated, or a particular currency/unit
- **Algorithms and representations**: Mathematical derivations, bit layouts, parser states, wire formats, or deliberately non-obvious optimizations
- **Security and privacy reasoning**: Threat assumptions, trust boundaries, redaction requirements, or why a check must precede another operation
- **Operational consequences**: What an operator must know to diagnose or recover from a failure
- **Deliberate non-action**: Why apparently dead, duplicate, or slower code must remain

State evidence and consequences, not folklore.

## When code should carry the meaning

Prefer code, types, or tests when the prose merely compensates for an avoidable representation problem:

- Replace `// check international` with `shipment.isInternational()` when that predicate is the actual concept.
- Replace `int timeout` plus `// milliseconds` with `Duration timeout` or an explicit unit-bearing name when the language lacks a duration type.
- Replace `boolean flag` plus branch narration with a named policy, mode, or sum type when the alternatives have domain meaning.
- Replace a repeated list of valid strings with an enum, parser, or value type that handles unknown values intentionally.
- Replace “must call A before B” with an API or state model that makes invalid ordering difficult when practical.
- Replace copied behavioral examples with executable tests when they can serve the same audience.

Do not force a type or abstraction whose only purpose is to avoid one clear local comment. The change must improve reliability or meaning enough to justify its cost.

## Choose the durable location

Use the narrowest place that owns the claim and reaches the intended audience:

| Information | Preferred location | Keep locally when |
|---|---|---|
| Meaning visible through a better identifier or type | Code | A non-obvious external reason still remains |
| One surprising line, ordering dependency, or implementation hazard | Nearby comment | Always; keep it adjacent to the affected code |
| Public behavior, preconditions, failures, side effects, or examples | Public doc comment / API reference | A call site has a distinct local hazard |
| Concept definition shared within a bounded context | Domain glossary / vocabulary ledger | A boundary needs an explicit translation note |
| Module-wide invariant, architecture, or extension model | Module/package documentation | A local section can violate it accidentally |
| Significant architectural decision, alternatives, and consequences | ADR | A concise local pointer prevents rediscovery |
| Executable behavior or usage example | Test, doctest, or compile-checked example | Narrative explains why the example matters |
| Operational procedure, diagnosis, or recovery | Runbook | The code emits an error or link that guides operators there |
| Temporary deferred work | Issue plus structured TODO when local visibility matters | The exact code location is necessary context |
| Historical narrative or authorship | Version control, changelog, incident record | The history imposes a current constraint |
| Tool suppression or generation metadata | Structured directive / generated header | The justification is not obvious from the directive |

Avoid duplicating the full same explanation in several places. Keep one authoritative version and add concise links or summaries tailored to each audience.

## Public contract documentation

Treat public docs as part of the contract, not as a restatement exercise. Include only what callers need and cannot reliably infer from the signature or surrounding conventions:

- Domain responsibility and terminology
- Preconditions, postconditions, and invariants
- Side effects and I/O
- Absence and failure semantics
- Units, currency, precision, time zone, clock, and inclusivity
- Ownership, lifecycle, mutation, and thread-safety expectations
- Ordering, concurrency, idempotency, retry, and transactional guarantees
- Security, authorization, privacy, and redaction requirements
- Compatibility and deprecation status
- Representative examples and important edge cases
- Panic/exception behavior when the ecosystem expects it

Do not write filler such as “Returns the customer ID” when `customerId(): CustomerId` already says that. Add the distinction that matters, for example that it is the billing-system identifier rather than a storefront or identity-provider identifier.

Follow the language ecosystem’s documentation conventions. Some ecosystems require documentation for exported symbols even when brief; satisfy that contract without padding it with noise.

Prefer executable or compile-checked examples where supported. Keep examples small, deterministic, safe to run, and focused on behavior callers may misunderstand.

## TODO FIXME and temporary notes

Use TODO/FIXME notes for concrete, temporary work—not permanent design explanations or vague dissatisfaction.

A durable temporary note should state:

1. **What remains unresolved**
2. **Why it cannot be resolved now** when that is not obvious
3. **The exit condition**: an issue, migration, version, date, event, or dependency after which it can be removed
4. **A real reference** when one exists

Example:

```java
// TODO(SHQ-1842): Remove legacy service-code translation after all persisted
// carrier configurations have been migrated to canonical codes.
```

Do not invent issue IDs, owners, deadlines, or removal versions. When no tracking system is available, state the concrete exit condition rather than writing `TODO: clean this up`.

Use `FIXME` only when the repository defines a meaningful distinction, commonly a known defect or unsafe behavior requiring correction. Follow local conventions rather than imposing universal tag semantics.

Avoid relative words such as `temporary`, `soon`, `new`, `old`, `legacy`, and `later` without an anchor. Name the version, migration, date, event, or contract that gives the word meaning.

Do not keep commented-out code as a work item. Version control preserves old code; an issue should preserve unresolved intent.

## Staleness and contradiction

Treat explanation drift as a correctness risk.

Search for staleness when:

- A symbol, domain term, state, or boundary representation is renamed.
- Behavior, error semantics, side effects, ordering, or defaults change.
- A workaround or compatibility bridge is removed.
- A schema, event, metric, or configuration key changes.
- Code is moved and a nearby explanation may no longer have the same owner.
- An example copies API usage that has changed.

When prose and code disagree:

1. Do not assume which is correct.
2. Identify the authoritative contract and executable evidence.
3. Check whether the contradiction reveals a code bug, test bug, stale explanation, or unresolved requirement.
4. Choose DEFER when the intended behavior cannot be established.
5. Fix all affected surfaces together once the truth is known.

After an edit, re-read the explanation without relying on the old code. Verify that pronouns, positional phrases such as “above”, and implementation details still make sense.

## Generated directive and legal comments

Treat these separately from ordinary explanatory prose:

- Preserve license and attribution text unless authorized policy says otherwise.
- Preserve generated-file markers and edit the generator or template instead of the output.
- Verify linter/compiler suppressions are narrow, necessary, and justified.
- Prefer a structured suppression scoped to the smallest element over a broad file-level disable.
- Remove obsolete suppressions after rerunning the tool.
- Do not rewrite machine-consumed directives for style.

## AI-assisted comment generation

Generate comments selectively. Do not blanket-comment every declaration or block.

Before adding a comment:

1. Identify a specific comprehension or contract gap.
2. Establish the claim from available evidence.
3. Determine why code, types, or tests are insufficient.
4. Choose the correct audience and location.
5. Write the smallest explanation that preserves the missing information.
6. Mark uncertainty rather than inventing rationale.

Avoid these AI failure modes:

- Paraphrasing every line
- Guessing business reasons from implementation
- Inventing incidents, performance measurements, vendor guarantees, or issue references
- Producing generic doc-comment filler to satisfy visual completeness
- Describing the current algorithm when the public contract should remain implementation-independent
- Deleting terse but essential warnings because they look redundant

Prefer no comment over a fabricated one. Prefer a precise open question or DEFER finding when evidence is missing.

## Examples

### Narration that should become code

Before:

```java
// Check whether the shipment is international.
if (!shipment.originCountry().equals(shipment.destinationCountry())) {
```

Better when the domain concept is correct:

```java
if (shipment.isInternational()) {
```

Disposition: **CONVERT**, paired with **EXTRACT** or **INTRODUCE CONCEPT** only if the predicate needs a meaningful owner or policy. Remove the original narration after tests establish equivalent behavior.

### Rationale that should remain

```java
// Carrier X reports Puerto Rico under its international region codes, but its
// customs contract treats these shipments as domestic. Do not derive customs
// requirements directly from the carrier region response.
```

Disposition: **KEEP** or **REWRITE** for precision. A good predicate name cannot preserve the vendor-contract mismatch by itself. Link the authoritative contract or issue when available.

### Public identifier distinction

Weak:

```java
/** Returns the customer ID. */
CustomerId customerId();
```

Useful when verified:

```java
/**
 * Returns the billing-system customer identifier.
 *
 * <p>This is distinct from storefront and identity-provider identifiers.
 */
BillingCustomerId customerId();
```

Disposition: **REWRITE**, possibly paired with **INTRODUCE CONCEPT** when one `CustomerId` type currently mixes several identifier domains.

### Architectural history in a method

Weak location:

```java
// In 2024 we discussed three queue systems ... [40 lines]
```

Disposition: **RELOCATE** the decision context, considered alternatives, and consequences to an ADR. Keep a one-line local note only when the chosen queue’s constraint affects safe maintenance.

### Unknown workaround

```java
// Must sleep here or production breaks.
Thread.sleep(250);
```

Disposition: **DEFER**. Search incidents, tests, blame/history, vendor docs, and timing contracts. Do not rewrite this as a confident explanation until the dependency is known; do not remove it merely because the comment is poor.
