# Semantic Surfaces

Use this reference when a concept appears in more than one code or operational surface, or when planning a terminology migration that extends beyond a local identifier.

## Contents

- [What is a semantic surface](#what-is-a-semantic-surface)
- [Core consistency rule](#core-consistency-rule)
- [Surface inventory](#surface-inventory)
- [Audit workflow](#audit-workflow)
- [Vocabulary ledger](#vocabulary-ledger)
- [Tests and examples as language](#tests-and-examples-as-language)
- [Errors and user-facing terms](#errors-and-user-facing-terms)
- [Events commands and state](#events-commands-and-state)
- [Logs metrics traces and operations](#logs-metrics-traces-and-operations)
- [Boundaries and intentional translation](#boundaries-and-intentional-translation)
- [Terminology migration](#terminology-migration)
- [Common failure modes](#common-failure-modes)

## What is a semantic surface

A semantic surface is any place where a concept is named, described, encoded, queried, or presented. Developers build a mental model from all of them, not identifiers alone.

A local rename can therefore be incomplete even when compilation succeeds. The old term may remain in tests, API fields, event schemas, errors, dashboards, documentation, or operational queries and continue to teach a conflicting model.

Audit only the surfaces relevant to the requested scope and migration risk. Do not turn every local rename into an organization-wide terminology project.

## Core consistency rule

Prefer one canonical term for one concept within a bounded context and audience, plus predictable grammatical variants:

- Noun/type: `ShipmentQuote`
- Command/request: `RequestShipmentQuote`
- Event/fact: `ShipmentQuoteRequested`
- Predicate: `isShipmentQuoteExpired`
- Collection: `shipmentQuotes`

Do not confuse grammatical variants with accidental synonyms. `RequestShipmentQuote` and `ShipmentQuoteRequested` express different temporal and behavioral roles while sharing a concept term.

Permit different words when:

- The concepts genuinely differ.
- Bounded contexts model the same real-world subject differently.
- An external contract is fixed.
- A user-facing term is intentionally clearer for that audience.
- A vendor representation must remain recognizable at its adapter boundary.

Make the translation explicit rather than letting aliases spread invisibly.

## Surface inventory

Consider these surfaces:

### Code model

- Variables, functions, methods, types, fields, modules, packages, and namespaces
- Generic parameters, annotations, attributes, decorators, and feature flags
- Domain policies, value objects, services, repositories, adapters, and translators

### Executable language

- Test names, fixtures, builders, factories, and assertions
- Examples, doctests, sample payloads, and contract tests
- Scenario/Gherkin vocabulary and acceptance criteria

### Explanation

- Inline comments and doc comments
- Module/package documentation
- Glossaries and architecture decision records
- Runbooks, playbooks, migration guides, and changelogs

### Contract and data

- URLs, endpoint names, query parameters, headers, and form fields
- JSON, GraphQL, RPC, protobuf, AsyncAPI, or OpenAPI names
- Database tables, columns, document fields, enum values, and indexes
- Configuration keys, environment variables, CLI commands, and flags

### Messaging and lifecycle

- Commands, events, topics, queues, consumer groups, and subscriptions
- State names, transition names, reason codes, and workflow activities

### Failure and operations

- Exception/error types, error codes, and messages
- Logs, structured attributes, metrics, units, trace/span names, and resource attributes
- Dashboards, alerts, recording rules, parsers, saved searches, and SLOs

### Product and integration

- UI labels, help text, notifications, emails, and support terminology
- Vendor payloads, external SDK types, partner documentation, and imported identifiers

## Audit workflow

### 1. Name the concept precisely

Write a one-sentence definition and identify its bounded context. Separate concepts that currently share one overloaded word.

### 2. Establish the canonical term

Use domain language, current contracts, and repository conventions. Record unresolved disputes rather than choosing a synonym by taste.

### 3. Search all relevant forms

Search:

- Exact current and proposed terms
- Singular/plural and grammatical variants
- Abbreviations, acronyms, aliases, and common misspellings
- Serialized forms such as snake case, kebab case, and uppercase environment keys
- Historical/deprecated terms
- Translated external or UI terms

Use semantic search or inspect schemas when a simple text search would miss generated or encoded names.

### 4. Classify each occurrence

For each occurrence, decide whether it is:

- Canonical usage
- Allowed grammatical variant
- Intentional boundary or audience translation
- Deprecated compatibility alias
- Accidental synonym or stale term
- A different concept that merely shares a word
- Unknown and requiring evidence

Do not bulk-replace before classification.

### 5. Decide the scope

Choose the smallest coherent change:

- Local code cleanup
- Bounded-context vocabulary correction
- Public contract migration
- Cross-service/event migration
- Product-language alignment
- Observability migration

A term can remain externally for compatibility while code adopts a canonical internal term through an explicit adapter.

### 6. Plan migration and verification

Identify producers, consumers, persisted data, queries, documentation, and compatibility windows. Add aliases or staged reads/writes only where required. Verify that retired terms no longer appear except in intentional compatibility or history records.

## Vocabulary ledger

Use a ledger for changes spanning multiple concepts or surfaces:

| Concept | Definition | Context | Canonical term | Allowed variants | External/UI term | Deprecated aliases | Owner/source |
|---|---|---|---|---|---|---|---|
| [Concept] | [One sentence] | [Bounded context] | [Term] | [Grammar forms] | [Explicit translations] | [Aliases to retire] | [Domain owner, contract, ADR] |

Rules:

- Define the concept before choosing the word.
- Record an authoritative owner or source when available.
- Do not list every spelling as an allowed alias; normalize deliberate forms.
- Mark externally fixed names as translations, not as preferred internal synonyms.
- Include removal conditions for deprecated aliases.
- Version the ledger with the code or domain documentation when it governs implementation.

## Tests and examples as language

Treat test names and examples as executable domain communication.

Prefer names that state the domain rule and outcome rather than implementation mechanics:

Weak:

```text
testProcess2
shouldCallRepositoryThreeTimes
```

Stronger when accurate:

```text
expiredQuotesAreNotOfferedAtCheckout
purchasingALabelRecordsTheCarrierTransaction
```

Do not hide useful technical behavior when the test is intentionally about infrastructure, such as retry timing, serialization compatibility, or transaction boundaries.

When renaming a concept:

- Update test names, fixtures, builders, and assertion messages.
- Check scenario language and sample payloads.
- Preserve compatibility tests that intentionally mention the old contract.
- Prefer executable examples for public usage when the ecosystem supports doctests or compile-checked snippets.
- Ensure examples demonstrate current error and edge-case semantics, not only the happy path.

A test name is not proof of intended behavior by itself. Reconcile it with assertions and the authoritative contract.

## Errors and user-facing terms

Errors are semantic interfaces. They may be consumed by humans, clients, support tooling, log parsers, and alerting systems.

Distinguish:

- **Error type/code**: Stable programmatic category
- **Developer message**: Diagnostic context without secrets
- **User-facing message**: Audience-appropriate language and recovery guidance
- **Structured attributes**: Machine-queryable identifiers and state

Guidance:

- Name the failed domain operation or violated rule, not only the low-level mechanism.
- Preserve causal information through wrapping/chaining rather than replacing it with a generic message.
- Avoid unstable prose parsing; provide stable codes or structured fields for automation.
- Do not leak secrets, personal data, tokens, raw payloads, or internal topology.
- Keep user-facing terminology aligned with the product vocabulary, even when internal or vendor terms differ.
- Update support documentation and alert rules when error categories change.

Do not rename a public error code as a local cleanup without a compatibility plan.

## Events commands and state

Use grammar to preserve temporal meaning:

- Commands request action: imperative or action-oriented forms such as `PurchaseLabel`.
- Events report facts: past-tense forms such as `LabelPurchased`.
- States describe conditions: noun/adjective forms such as `InTransit` or `DeliveryFailed`.
- Policies answer decisions: names such as `ShipmentEligibilityPolicy` or `allowsShipment`.

Do not use one broad event name for facts with materially different semantics merely to simplify naming. Conversely, do not split events when consumers need the same stable transition envelope and the distinction is already explicit in its payload.

Check:

- Producer and consumer meanings
- Event-time versus processing-time semantics
- Idempotency and replay behavior
- Schema/version compatibility
- Topic and subscription names
- Dead-letter and observability terminology
- Historical events stored for replay or audit

## Logs metrics traces and operations

Observability vocabulary should make the same operation recognizable across logs, metrics, traces, dashboards, and alerts.

### General guidance

- Use stable names based on operations and domain concepts, not incidental implementation details.
- Prefer structured attributes over embedding changing values in names or message templates.
- Reuse established semantic conventions from the instrumentation ecosystem when they fit.
- Keep names and attributes low-cardinality where aggregation systems require it; never place customer IDs, order IDs, URLs with IDs, or raw error messages in metric names or other bounded-label dimensions.
- Record units and aggregation semantics explicitly for metrics.
- Distinguish attempts, successes, failures, durations, sizes, and current-state gauges.
- Make trace/span names represent stable operations; put variable details in attributes.
- Preserve error causes and domain outcome attributes without exposing sensitive data.

### Migration consequences

When changing an observability name or attribute:

- Update instrumentation and tests.
- Update dashboards, alerts, recording rules, SLO queries, log parsers, saved searches, and runbooks.
- Consider dual emission only when operational continuity justifies its cost.
- Define the overlap and removal condition.
- Verify historical-data expectations; old dashboards may still need the prior name for earlier time ranges.

Do not label a metric rename “internal” merely because it is not a customer API. Operational dependencies are contracts too.

## Boundaries and intentional translation

Keep external-system vocabulary at the adapter when it differs from the domain model.

Example:

```text
ShopifyOrderPayload --translate--> Order
Order --present--> CheckoutOrderSummary
Order --persist--> OrderRecord
```

These names can all be correct because they identify different representations and audiences. Avoid aliases such as `Order2`, `OrderModel`, or `OrderData` that do not state the boundary.

When product language intentionally differs from engineering language, document the mapping:

| Internal concept | Product term | Reason |
|---|---|---|
| `ShipmentQuote` | “Shipping options” | Customers choose an option; they do not reason about quotation lifecycle |

Do not force UI language into the domain model when it erases a needed distinction. Do not expose internal jargon to users merely for code consistency.

## Terminology migration

Use this sequence for a broad rename:

1. Define the concept, canonical term, context, and affected audiences.
2. Inventory current aliases and semantic surfaces.
3. Classify each alias as accidental, intentional translation, or compatibility contract.
4. Add characterization and contract tests.
5. Introduce the new internal name or model.
6. Add boundary translation or compatibility aliases where required.
7. Migrate producers, consumers, stored data, queries, docs, tests, and observability in a controlled order.
8. Communicate deprecation and removal conditions.
9. Search for stale terms and validate all supported paths.
10. Remove compatibility forms only after the agreed condition is met.

Separate mechanical renames from behavioral or schema changes so failures are diagnosable.

## Common failure modes

- **Blind global replacement**: Changes unrelated concepts sharing the same word.
- **Global vocabulary absolutism**: Forces one model across bounded contexts.
- **Alias accumulation**: Adds a new term but never retires the old one.
- **Grammar flattening**: Uses the same noun for commands, events, states, and policies.
- **Observability omission**: Code changes while dashboards and alerts continue using the old term.
- **Contract denial**: Treats config keys, event names, errors, or metric names as non-contractual because they are not source APIs.
- **Documentation-only alignment**: Glossaries change but code and tests continue teaching different language.
- **Code-only alignment**: Compilation passes while user-facing and operational surfaces drift.
- **Audience erasure**: Forces internal jargon onto customers or vendor terms into the domain.
- **Temporal ambiguity**: Uses `new`, `old`, `temporary`, `legacy`, `soon`, or `v2` without a stable version, date, migration, or removal condition.
- **Unbounded labels**: Encodes high-cardinality or sensitive values into metrics or operation names.
