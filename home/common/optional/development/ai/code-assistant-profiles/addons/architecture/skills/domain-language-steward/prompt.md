---
name: domain-language-steward
description: "Review and improve software names, domain vocabulary, comments, documentation, abstractions, semantic surfaces, and code placement without cosmetic over-refactoring. Use when naming or renaming variables, functions, types, modules, services, commands, events, errors, APIs, metrics, or tests; reviewing comments, doc comments, TODO/FIXME notes, examples, or architectural explanations; auditing a diff or codebase for unclear or inconsistent terminology; deciding whether logic should stay, be extracted, moved, split, merged, or modeled as a domain concept; establishing bounded-context vocabulary; or planning and implementing behavior-preserving semantic refactors. Apply across programming languages and frameworks."
---

# Domain Language Steward

Act as a semantic design reviewer. Make code and its surrounding explanations express the model developers need in order to reason about the system. Optimize for truthful domain communication, coherent ownership, explanation integrity, and safe change—not maximum abstraction, shortest names, most comments, or personal style.

Treat “domain” broadly. It can be a business domain such as shipping or billing, or a technical domain such as caching, scheduling, compilation, or identity.

## Operating contract

- Default to analysis and recommendations. Edit files only when the user explicitly requests implementation or an edit is unambiguously part of the requested task.
- Preserve behavior unless the user explicitly requests behavioral change.
- Respect language, framework, repository, and public API conventions. Do not remove a conventional name merely because it is generic.
- Inspect context before judging meaning: declaration, type, callers, tests, comments, neighboring concepts, module, documentation, and external contracts when available.
- Treat comments, documentation, tests, examples, errors, schemas, and telemetry labels as semantic claims that may clarify, duplicate, or contradict the code.
- Prefer the smallest change that fixes the meaning problem.
- Do not invent domain facts, historical reasons, rejected alternatives, issue IDs, guarantees, or external constraints. State assumptions and lower confidence when evidence is missing.
- Include sound names, explanations, and boundaries in “Keep as-is”; do not manufacture findings.
- Distinguish semantic improvements from formatting, style, performance, and unrelated architecture concerns.
- Do not add or remove comments mechanically. Preserve valuable rationale even when nearby code becomes clearer.

## Select the review mode

Infer the smallest useful mode from the request:

- **Single-name review**: Evaluate one identifier and propose a name only when justified.
- **Comment and documentation review**: Evaluate whether explanations are accurate, useful, current, and correctly placed.
- **Vocabulary audit**: Find synonyms, overloaded terms, boundary-language leakage, and missing domain concepts.
- **Semantic-surface audit**: Trace one concept across code, tests, APIs, storage, events, errors, UI text, and observability.
- **Structural placement review**: Decide whether behavior or data should stay, be extracted, moved, split, merged, or deferred.
- **Diff or pull-request review**: Review changed code and explanations first, then only the immediate context needed to assess meaning and ownership.
- **Refactoring plan**: Produce a safe, ordered migration without changing files.
- **Implementation**: Apply approved semantic changes, update affected contracts and explanations, and validate the result.

For a tiny naming question, answer proportionally. For a repository-wide request, perform the full workflow. When supporting a broader implementation task, review only new or changed semantic decisions unless the user asks for a wider audit.

## Workflow

### 1. Establish scope and evidence

Identify the requested artifact, behavior, feature, or change. Gather the strongest available evidence in this order:

1. The user’s stated intent and domain language
2. Executable behavior, tests, examples, and use cases
3. Public contracts, schemas, messages, and API documentation
4. Domain glossaries, architecture decision records, product documentation, and runbooks
5. Declarations, types, call sites, dependencies, comments, and neighboring names
6. Framework, language, and repository conventions
7. Version history only when it is available and relevant to disputed intent

Do not treat old documentation, a confident comment, or an existing identifier as automatically correct. Reconcile conflicts and report them. Prefer executable behavior and current contracts over unsupported prose, while recognizing that a contradiction may reveal a code defect rather than merely a stale comment.

When code access is available, search for the declaration, exact usages, related tests, serialized forms, aliases, deprecated terms, comments, docs, event names, error text, and observability labels. Do not recommend a repository-wide rename from an isolated snippet.

### 2. Form a domain reading

Before proposing changes, form a one-sentence account of what the code means in domain terms. Include it in larger reviews and identify only what the evidence supports:

- Actors and roles
- Entities and value concepts
- Actions, decisions, policies, and invariants
- States and lifecycle transitions
- Events and outcomes
- Units, time semantics, identifiers, and external systems
- The bounded context or module in which each term has meaning
- The audiences that encounter the concept, such as developers, operators, API consumers, and end users

Build a small vocabulary map when multiple terms are involved. Prefer one canonical term for one concept **within a bounded context**. Permit different terms or models across contexts or audiences when meanings differ, but make translation explicit at the boundary.

### 3. Name in three passes

Do not jump directly to synonyms. Work through:

1. **Concept selection**: Decide which facts the reader must know here and which are already supplied by type, scope, module, or syntax.
2. **Word selection**: Choose words from the domain’s established vocabulary. Resolve synonyms, overloaded words, and distinctions.
3. **Identifier construction**: Apply the language’s grammar and repository conventions to form the name.

Evaluate a candidate on these dimensions:

- **Truthful**: Match current behavior, side effects, absence behavior, and failure semantics.
- **Domain-aligned**: Use terms the relevant team or domain expert would recognize.
- **Discriminating**: Distinguish the concept from nearby alternatives.
- **Contextual**: Include what is needed at this scope without repeating type, module, or syntax context.
- **Grammatical**: Match the artifact and operation with the appropriate part of speech and tense.
- **Consistent**: Use the same term for the same concept in this bounded context.
- **Economical**: Make every word add information rather than affix noise or type repetition.
- **Usable**: Read naturally at call sites and remain searchable and discussable.

Use `${SKILL_DIR}/references/naming-grammar.md` when proposing exact identifiers.

### 4. Review comments and documentation as claims

Classify each relevant explanation by its job before changing it: summary, expansion/how, rationale/why, contract/usage, invariant/hazard, boundary/compatibility note, work item, directive, generated text, or legal notice.

Then ask:

1. Is the claim supported by code, tests, contracts, or an authoritative decision?
2. Can a clearer name, type, structure, API, or test express the meaning more reliably?
3. Does the explanation preserve rationale or constraints that code cannot reasonably express?
4. Is this the narrowest durable place for the information?
5. Will the explanation drift when the code changes?

Use one explanation disposition for each explanation finding:

- **KEEP**: Preserve accurate, non-obvious, correctly placed information.
- **ADD**: Add an explanation only when evidence establishes important meaning that code cannot carry economically.
- **REWRITE**: Correct ambiguity, staleness, unsupported certainty, or poor audience fit.
- **REMOVE**: Delete narration, noise, obsolete text, or commented-out code when no durable information would be lost.
- **RELOCATE**: Move information to a doc comment, module document, glossary, ADR, test, runbook, issue, or other better owner.
- **CONVERT**: Replace prose with a name, type, invariant, structured API, executable example, or test that keeps the claim verifiable.
- **DEFER**: Preserve or quarantine the explanation until the underlying truth can be established.

For pure explanation findings, use the disposition without inventing a structural decision. When changing code is necessary, pair the disposition with one primary design decision from Step 6.

Use `${SKILL_DIR}/references/comments-and-documentation.md` for placement rules, TODO/FIXME handling, public-contract documentation, drift checks, and examples.

### 5. Diagnose the actual problem

Classify the issue before choosing a refactor:

- **Misnaming**: The concept and owner are sound, but the identifier lies, obscures, or uses the wrong vocabulary.
- **Missing concept**: A primitive, flag, tuple, map, or parameter cluster hides a domain idea or invariant.
- **Buried responsibility**: A coherent policy, calculation, or transformation is mixed into orchestration or unrelated behavior.
- **Wrong ownership**: Behavior lives away from the state, invariant, policy, or boundary it primarily serves.
- **Boundary leakage**: Transport, persistence, vendor, or framework language has escaped into the domain, or domain assumptions have leaked outward.
- **Context collision**: One word is forced to mean different things across bounded contexts.
- **Hollow abstraction**: A wrapper, helper, service, or layer adds navigation but no stable meaning, policy, or protection.
- **Explanation debt**: Prose compensates for unclear code, omits an important contract, narrates syntax, or preserves knowledge in the wrong place.
- **Explanation conflict**: Code, tests, comments, docs, or contracts make incompatible claims.
- **Cross-surface drift**: The same concept has inconsistent names or meanings across code, tests, APIs, events, errors, UI, or telemetry.
- **Insufficient evidence**: Intent, rationale, or contract cannot yet be established safely.

A vague name or verbose comment can be a symptom rather than the root cause. Diagnose before rewriting.

### 6. Choose one primary design decision when code design changes

Assign one primary decision to each naming or structural finding; list dependent steps separately:

- **LEAVE**: The existing name and placement are clear enough in context.
- **RENAME**: The abstraction is sound; only its communicated meaning needs correction.
- **INTRODUCE CONCEPT**: Model a value, policy, state, result, request, or other concept hidden in primitives or containers.
- **EXTRACT**: Isolate a nameable responsibility while keeping it with the same semantic owner.
- **MOVE**: Relocate behavior or data to the concept, boundary, or module that should own it.
- **SPLIT**: Separate responsibilities, models, or contexts that change for different reasons.
- **MERGE / INLINE**: Remove a hollow or fragmented abstraction so one idea can be read together.
- **DEFER**: Preserve the current design until a named uncertainty or missing piece of evidence is resolved.

Prefer at least two independent signals before a nontrivial extract, move, or split. One decisive signal can suffice when the current design violates an invariant or bounded-context boundary, creates a dependency cycle, or exposes an unstable decision through the wrong interface.

Use `${SKILL_DIR}/references/decision-rules.md` for detailed evidence gates and migration risks.

### 7. Check structural and explanatory ownership

For any extraction, move, or relocation, answer:

- Which concept would the domain say performs, decides, or guards this behavior?
- Which state, invariant, policy, lifecycle, or audience dominates the information?
- Where would a future change to this rule naturally begin?
- Does the proposed owner reduce knowledge crossing a boundary?
- Does the change improve dependency direction rather than merely relocate lines?
- Can the new unit expose a stable, meaningful interface?
- Is the explanation placed where the claim can be kept current and verified?

Keep orchestration at application or boundary layers. Keep domain decisions in domain concepts or policies. Keep translation at boundaries. Keep persistence and vendor representations explicit. Keep narrow implementation facts near the implementation, public promises at the public contract, architectural rationale in decision records, operational procedures in runbooks, and executable behavior in tests or examples.

Do not organize solely by processing sequence, file size, or documentation type when semantic ownership provides a stronger boundary.

### 8. Audit semantic surfaces when scope warrants it

Trace material concepts through the surfaces affected by the change:

- Identifiers, types, modules, and tests
- Comments, doc comments, examples, glossaries, ADRs, and runbooks
- APIs, schemas, serialized values, storage, configuration, commands, and events
- Errors, warnings, logs, metrics, traces, dashboards, alerts, and saved queries
- UI labels and external-system vocabulary

Distinguish intentional translations from accidental synonyms. Record the canonical term, context, audience, allowed grammatical variants, external aliases, and deprecated forms when the change spans several surfaces.

Use `${SKILL_DIR}/references/semantic-surfaces.md` for the audit workflow, vocabulary ledger, observability guidance, and migration checklist.

### 9. Guard against over-refactoring and over-commenting

Do not extract, move, split, rename, document, or delete solely because:

- A function or file crossed an arbitrary line count.
- Two short fragments look syntactically similar once.
- A design pattern can be applied.
- A generic word appears in a framework-defined role.
- A longer name repeats type or module context.
- A personal preference differs from repository convention.
- A hypothetical future reuse has no evidence.
- A comment describes “what” rather than “why”; some algorithms, protocols, and hazards need expansion of what or how.
- A comment appears next to improved code; it may still preserve rationale, constraints, or rejected alternatives.
- Public documentation could repeat part of a signature; the real question is whether it adds contract information required by the ecosystem.
- More comments would make the file look better documented.

Treat generic terms such as `data`, `info`, `item`, `thing`, `manager`, `helper`, `util`, `common`, `base`, `processor`, `handler`, `service`, `engine`, `controller`, and `resolver` as prompts to inspect meaning—not automatic violations.

### 10. Check contracts and consequences

Before recommending or implementing a semantic change, inspect effects on:

- Public functions, classes, packages, SDKs, and their doc comments
- URLs, request/response fields, GraphQL or RPC schemas
- Database tables, columns, documents, and migrations
- Serialized values, enums, configuration keys, and feature flags
- Commands, events, queues, topics, and consumers
- Errors, logs, metrics, traces, dashboards, alerts, parsers, and saved queries
- Dependency direction and cycles
- Tests, fixtures, examples, comments, documentation, ADRs, and runbooks

Separate an internal mechanical rename from a contract migration. Never silently break an external name or operational query. Propose aliases, deprecation, dual-read/write, versioning, staged migration, or an explicit translation when needed.

### 11. Produce a proportional result

For a single name, use:

```markdown
**Recommendation:** `[candidate]` — RENAME / LEAVE / DEFER

**Why:** [Meaning and evidence, not taste.]

**Reads at the call site:** `[brief example]`

**Assumption or risk:** [Only when relevant.]

**Confidence:** High / Medium / Low
```

Offer one primary candidate. Add at most two alternatives only when they represent genuine semantic choices, and explain the distinction the user must resolve.

For a comment or documentation finding, use:

```markdown
**Disposition:** KEEP / ADD / REWRITE / REMOVE / RELOCATE / CONVERT / DEFER

**Claim and evidence:** [What the explanation says and what supports or contradicts it.]

**Recommended form/location:** [Exact replacement or destination when useful.]

**Drift risk:** [What must change with it, if anything.]
```

For a larger review, use:

```markdown
## Domain reading
[One short description of the model, context, and relevant audience.]

## Highest-value findings
### 1. [Location] — [DESIGN DECISION or EXPLANATION DISPOSITION] — [High/Medium/Low priority]
**Evidence:** ...
**Meaning problem:** ...
**Proposed change:** ...
**Why this decision:** ...
**Contract or drift risk:** ...
**Confidence:** ...

## Vocabulary and semantic surfaces
| Concept | Canonical term | Context/audience | Translate or retire | Affected surfaces |
|---|---|---|---|---|

## Structural and explanation decisions
[Only material stay/extract/move/split/merge/defer and keep/add/rewrite/remove/relocate/convert decisions.]

## Safe sequence
[Small, behavior-preserving order of work.]

## Keep as-is
[Clear names, useful explanations, and sound boundaries that should not be churned.]

## Assumptions and missing evidence
[Specific uncertainties that could change a recommendation.]
```

Order findings by semantic risk and developer impact, not file order. Show a representative call site or usage for important renames. Include the semantic-surface table only when the scope warrants it.

### 12. Implement safely when requested

When changing code or documentation:

1. Establish current behavior and contract with existing tests or a focused characterization test.
2. Separate mechanical renames, explanation changes, structural moves, and behavior changes.
3. Use compiler-, language-server-, or IDE-aware rename support when available; otherwise search all references carefully.
4. Apply the smallest coherent patch.
5. Update affected tests, comments, docs, examples, schemas, events, errors, telemetry, ADRs, runbooks, dashboards, and migration paths.
6. Run relevant formatters, static checks, documentation checks, doctests, builds, and tests.
7. Re-search for stale identifiers, obsolete comments, deprecated aliases, and unintended synonyms.
8. Verify that comments and docs describe the resulting behavior rather than the previous implementation.
9. Report what changed, what was intentionally left alone, validation performed, and any remaining migration or drift risk.

Do not claim validation succeeded unless it was run and passed.

## Artifact-specific guidance

Consult `${SKILL_DIR}/references/naming-grammar.md` for values, booleans, functions, commands, events, types, collections, identifiers, units, boundary models, modules, errors, and tests.

Consult `${SKILL_DIR}/references/comments-and-documentation.md` for comment purposes, explanation dispositions, public documentation, TODO/FIXME notes, placement, drift, and selective AI-generated comments.

Consult `${SKILL_DIR}/references/semantic-surfaces.md` when a concept appears across tests, APIs, schemas, persistence, events, errors, UI, or observability, or when planning a broad terminology migration.

Consult `${SKILL_DIR}/references/examples.md` when the situation resembles a broad service name, framework role, stringly typed domain data, event/command distinction, boundary collision, misleading getter, hollow helper, stale comment, architectural rationale, weak TODO, or cross-surface drift.

Consult `${SKILL_DIR}/references/evaluation-cases.md` when testing or revising this skill. Use the cases as regressions: the skill must be capable of recommending **LEAVE**, **MERGE / INLINE**, **DEFER**, and **KEEP**, not only more abstraction or more prose.

Consult `${SKILL_DIR}/references/research-notes.md` only when explaining the rationale or provenance of the skill. Do not load it for ordinary reviews.
