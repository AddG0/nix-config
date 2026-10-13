# Decision Rules

Use this reference when choosing among LEAVE, RENAME, INTRODUCE CONCEPT, EXTRACT, MOVE, SPLIT, MERGE / INLINE, and DEFER.

## Contents

- [Fast decision sequence](#fast-decision-sequence)
- [Decision matrix](#decision-matrix)
- [Evidence for structural change](#evidence-for-structural-change)
- [Explanation burden as evidence](#explanation-burden-as-evidence)
- [Semantic ownership](#semantic-ownership)
- [Bounded contexts and boundaries](#bounded-contexts-and-boundaries)
- [Contract and migration risk](#contract-and-migration-risk)
- [Priority and confidence](#priority-and-confidence)
- [Common false positives](#common-false-positives)

## Fast decision sequence

1. Ask whether the reader’s misunderstanding can be fixed without changing the abstraction.
   - If yes, choose **RENAME**.
2. Ask whether the code lacks a first-class concept that carries meaning, validity, units, state, or policy.
   - If yes, choose **INTRODUCE CONCEPT**.
3. Ask whether a coherent responsibility is buried inside a larger owner but belongs to that same owner.
   - If yes, choose **EXTRACT**.
4. Ask whether that responsibility primarily belongs to another concept or boundary.
   - If yes, choose **MOVE** rather than extract-and-leave.
5. Ask whether one abstraction combines models or responsibilities that vary independently.
   - If yes, choose **SPLIT**.
6. Ask whether an abstraction has no independent meaning, policy, invariant, lifecycle, substitution, or boundary value.
   - If yes, choose **MERGE / INLINE**.
7. Ask whether the current code is already clear in context.
   - If yes, choose **LEAVE**.
8. If a material fact remains unknown and the safe choice depends on it, choose **DEFER** and name the evidence needed.

Do not use this as a mechanical checklist. A decision must explain what becomes easier to understand, protect, or change.

For a pure comment or documentation issue, do not force one of these design decisions. Use KEEP, ADD, REWRITE, REMOVE, RELOCATE, CONVERT, or DEFER from `comments-and-documentation.md`. Pair an explanation disposition with a design decision only when code or structure must also change.

## Decision matrix

| Decision | Choose when | Strong evidence | Do not choose when |
|---|---|---|---|
| **LEAVE** | The name is truthful and sufficiently distinctive at its scope; placement follows semantic ownership | Call sites read naturally; vocabulary is consistent; no hidden contract or boundary issue | A better name is merely prettier or longer |
| **RENAME** | The abstraction is correct but the identifier misstates behavior, uses the wrong domain word, or omits a needed distinction | Callers reveal a different verb/noun; tests contradict the name; a canonical term exists | The real problem is mixed responsibility, missing type, or wrong ownership |
| **INTRODUCE CONCEPT** | Primitives or generic containers hide a domain value, invariant, state, result, policy, request, or unit | Repeated validation; parameter clusters; invalid combinations; repeated conversions; boolean blindness; stringly typed states/IDs | The wrapper would only rename a value with no behavior, invariant, unit, or semantic distinction |
| **EXTRACT** | A nameable responsibility is buried inside a larger operation but belongs to the same owner | Independent rule/calculation; meaningful test seam; repeated business rule; abstraction reduces cognitive load at the call site | Extraction creates a one-line indirection, exposes many internals, or separates inseparable steps |
| **MOVE** | Behavior primarily knows or protects another concept’s state, invariant, policy, or boundary | Feature envy; wrong dependency direction; repeated cross-object queries; domain rule in controller/adapter; boundary translation scattered | The target would become a miscellaneous dumping ground or require more knowledge crossing the boundary |
| **SPLIT** | One abstraction contains responsibilities or models that change independently or use conflicting vocabularies | Distinct reasons to change; distinct owners/lifecycles; bounded-context collision; optional dependencies; unrelated invariants | The split merely mirrors processing steps or produces anemic fragments with constant coordination |
| **MERGE / INLINE** | An abstraction adds navigation without stable meaning or protection | Pass-through wrapper; synonym-only interface; one-use helper obscures flow; layers always change together | The abstraction protects volatility, marks a boundary, enforces policy, or provides a valuable test/substitution seam |
| **DEFER** | A decision depends on missing domain or contract evidence | Ambiguous verb semantics; unclear side effects; unknown external consumers; disputed canonical term | Evidence is available but has not been inspected |

## Evidence for structural change

Prefer at least two independent signals for a nontrivial EXTRACT, MOVE, or SPLIT. Count evidence categories, not repeated examples of the same fact.

### Meaning signal

- The responsibility has a stable name in domain language.
- Domain conversations or use cases treat it as a distinct decision, policy, state, or process.
- The current name requires words such as “and”, “or”, “misc”, or “everything” because concepts are mixed.

### Invariant signal

- A rule must always hold for a value or lifecycle.
- Validation is repeated at multiple creation or mutation points.
- Invalid combinations are representable because related data is dispersed.

### Change-coupling signal

- Changes to one business rule repeatedly touch unrelated orchestration or infrastructure.
- Two parts of an abstraction have different reasons, cadence, or owners for change.
- A volatile decision leaks through several modules instead of being hidden behind one interface.

### Dependency signal

- A domain rule depends on a controller, transport DTO, ORM entity, or vendor SDK.
- A high-level concept imports low-level details it should not know.
- A dependency cycle or bidirectional knowledge exists.

### Boundary signal

- External names or representations are used as if they were the domain model.
- Translation logic is duplicated or scattered.
- The same term has different meanings in distinct contexts.

### Cohesion signal

- Behavior reads mostly one other concept’s data.
- Callers repeatedly assemble the same inputs to ask the same domain question.
- A proposed unit can expose a small interface and hide meaningful detail.

### Testability signal

- A deterministic policy or calculation is trapped inside I/O-heavy orchestration.
- A focused test would express a domain rule more clearly than the current integration-only test.

Testability alone is not enough if the resulting abstraction has no semantic meaning.

## Explanation burden as evidence

Comments and documentation can reveal a semantic design problem, but prose volume alone is not a refactoring rule. Treat the explanation burden as evidence when:

- Several comments repeatedly translate generic names into the same domain concept.
- A caller must read implementation comments to understand ordinary API behavior.
- A prose invariant is duplicated at multiple mutation points.
- A comment describes a coherent policy that has no name in code.
- Documentation repeatedly warns that two same-typed identifiers, units, or states must not be confused.
- A long local comment explains a decision owned by another module, boundary, or architecture record.
- Comments, tests, contracts, and telemetry use conflicting terms for one concept.

First verify the claim. Then decide whether to rename, introduce a concept, extract, move, or relocate the explanation. Do not refactor merely because a comment is long, and do not delete the only evidence of a constraint before a durable replacement exists.

A comment-only problem may need only REWRITE, REMOVE, or RELOCATE. An explanation that accurately records rationale may deserve KEEP even when no code change follows.

## Semantic ownership

Place behavior with the concept that can answer the domain question with the least leaked knowledge.

Use these probes:

1. **Language probe**: In a domain sentence, who performs or decides the verb?
2. **Knowledge probe**: Whose state, invariant, policy, or lifecycle dominates the implementation?
3. **Change probe**: Which module should own future changes to this rule?
4. **Boundary probe**: Which side should translate or conceal representation details?
5. **Dependency probe**: Which direction keeps domain policy independent of delivery and storage mechanisms?
6. **Interface probe**: Can the proposed owner expose a smaller and more stable contract?

Avoid simplistic “data plus methods” placement. A policy involving several entities may belong in a named domain policy rather than arbitrarily on one entity. Orchestration that coordinates I/O may remain in an application service while delegating decisions to domain concepts.

### Typical placement

| Responsibility | Likely owner | Caveat |
|---|---|---|
| HTTP/RPC parsing and response mapping | Controller, resolver, endpoint adapter | Do not place domain decisions here |
| Vendor-specific payload conversion | Named integration adapter/translator | Keep vendor terms at this boundary |
| Persistence mapping and query mechanics | Repository or persistence adapter | Do not make the record the domain model by default |
| Cross-entity business decision | Named domain policy/service | Use a precise domain name, not a generic dumping ground |
| Entity/value invariant | Entity, value object, constructor/factory | Keep invalid states hard or impossible to create |
| Workflow coordination and I/O sequencing | Application service/use case | Delegate calculations and policy decisions |
| Cache key/expiry/routing policy | Cache policy or cache-owning component | A framework `CacheResolver` can remain valid when it precisely names the role |
| Public behavior, failure semantics, and usage | Public API documentation / doc comment | Keep implementation details out unless callers can observe or must account for them |
| Cross-cutting architectural choice and alternatives | Architecture decision record | Keep a concise local pointer only when the constraint affects safe maintenance |
| Operational diagnosis and recovery | Runbook | Make errors and alerts lead operators to the authoritative procedure |
| Narrow implementation hazard or external quirk | Nearby comment | Verify the claim and link an authoritative source when available |

## Bounded contexts and boundaries

Apply consistency within a bounded context, not blindly across the entire organization.

- Use one canonical term for one concept inside a context.
- Do not force two genuinely different concepts to share a universal model because they have the same everyday word.
- Allow the same word to have context-qualified models when meaning differs, such as `billing.Customer` and `support.Customer`.
- Make context translation explicit through mappers, adapters, anti-corruption layers, events, or APIs.
- Name boundary representations when confusion is possible: `Order`, `ShopifyOrderPayload`, `OrderRecord`, and `OrderResponse` may each be correct.
- Keep domain code free from external-system vocabulary unless the external concept truly is part of the domain.

A context split is not justified by folder preference alone. Look for language, model, ownership, lifecycle, or policy differences.

## Contract and migration risk

Classify the identifier before changing it.

| Surface | Typical risk | Safer migration |
|---|---|---|
| Local variable/private helper | Low | Mechanical rename plus tests |
| Internal type/module used across repository | Medium | Search all references; staged internal changes if needed |
| Public source API/SDK symbol | High | Add new symbol, deprecate old alias, document removal window |
| JSON/GraphQL/RPC field or enum | High | Version, alias, dual read/write, compatibility tests |
| Database table/column/value | High | Expand-migrate-contract; backfill; compatibility period |
| Event type/topic/payload | Very high | Version or dual publish/consume; coordinate consumers; replay compatibility |
| Config key/environment variable | High | Support old and new keys temporarily; precedence warning |
| Log/metric/trace name | Medium to high | Update dashboards, alerts, parsers, saved queries, and runbooks |
| Public doc comment / generated API reference | Medium to high | Update source docs, generated output, examples, links, and compatibility statements together |
| Error type/code/message | Medium to high | Preserve stable programmatic categories; update clients, support tooling, parsers, and user guidance |

Never present a high-risk contract rename as a simple cleanup. Explain the migration and whether the semantic value justifies it.

### Safe semantic-refactor order

1. Add characterization or contract tests.
2. Introduce the new concept/name alongside the old contract when compatibility is required.
3. Move or extract behavior without changing results.
4. Migrate internal callers.
5. Migrate external producers/consumers through a staged plan.
6. Update comments, public docs, examples, errors, observability, dashboards, and runbooks.
7. Run documentation checks and re-search for stale terms and contradictory claims.
8. Remove aliases only after the compatibility window and verification.

## Priority and confidence

### Priority

- **High**: The name or placement can cause wrong behavior, violate an invariant, blur a security/financial boundary, or mislead frequent changes and public contracts.
- **Medium**: The problem creates recurring comprehension cost, feature scattering, or vocabulary drift but is not immediately dangerous.
- **Low**: The improvement is local, low-frequency, and mostly editorial. Recommend only when change cost is small.

### Confidence

- **High**: Declaration, usages, tests/contracts, and domain vocabulary agree.
- **Medium**: Code behavior is visible, but canonical vocabulary or external impact is uncertain.
- **Low**: Only an isolated snippet or partial description is available.

A low-confidence finding should usually be DEFER or a conditional recommendation, not an assertive rewrite.

## Common false positives

- `Controller`, `Resolver`, `Repository`, `Factory`, or `Handler` precisely identifies a framework or architectural role.
- A short name is unambiguous because the type, module, and local scope supply the rest of the meaning.
- Two snippets are syntactically similar but represent different domain rules that will evolve independently.
- A one-use helper keeps a complex domain condition named and readable; one use does not automatically make it hollow.
- A wrapper protects an unstable vendor dependency even if it currently forwards calls.
- Two bounded contexts intentionally model `Customer` differently.
- A long identifier repeats type, namespace, and method context; making it longer would add noise rather than meaning.
- A broad service name looks suspicious, but its responsibilities have not yet been inspected.
- A concise rationale comment records an external constraint that a better identifier cannot express.
- A parser or protocol comment explains a non-obvious representation or algorithm; “what/how” is not automatically noise.
- An exported symbol needs a brief doc comment because the language ecosystem or generated documentation requires it.
- A TODO is locally valuable because it names concrete deferred work and a real removal condition.
- A different user-facing term is an intentional audience translation rather than accidental vocabulary drift.
