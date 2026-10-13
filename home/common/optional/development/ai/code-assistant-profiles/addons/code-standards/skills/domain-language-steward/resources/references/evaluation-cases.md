# Evaluation Cases

Use these cases to test changes to the skill. A strong response must make a semantic decision, cite available evidence, avoid inventing domain facts or rationale, preserve useful explanations, and address contract and drift risk proportionally.

## Contents

- [Scoring rubric](#scoring-rubric)
- [Case 1: Framework-mandated role](#case-1-framework-mandated-role)
- [Case 2: Overloaded term across contexts](#case-2-overloaded-term-across-contexts)
- [Case 3: Public serialized field](#case-3-public-serialized-field)
- [Case 4: Affix-heavy name](#case-4-affix-heavy-name)
- [Case 5: Stringly typed concept](#case-5-stringly-typed-concept)
- [Case 6: Line-count-only move](#case-6-line-count-only-move)
- [Case 7: No findings](#case-7-no-findings)
- [Case 8: Advice versus implementation](#case-8-advice-versus-implementation)
- [Case 9: Missing context](#case-9-missing-context)
- [Case 10: Event migration](#case-10-event-migration)
- [Case 11: Duplicate code with different meaning](#case-11-duplicate-code-with-different-meaning)
- [Case 12: Wrong owner with decisive evidence](#case-12-wrong-owner-with-decisive-evidence)
- [Case 13: Narrating inline comment](#case-13-narrating-inline-comment)
- [Case 14: Necessary vendor-rationale comment](#case-14-necessary-vendor-rationale-comment)
- [Case 15: Comment and code disagree](#case-15-comment-and-code-disagree)
- [Case 16: Vague TODO](#case-16-vague-todo)
- [Case 17: Public doc comment repeats the signature](#case-17-public-doc-comment-repeats-the-signature)
- [Case 18: Architectural decision buried in code](#case-18-architectural-decision-buried-in-code)
- [Case 19: Cross-surface vocabulary drift](#case-19-cross-surface-vocabulary-drift)
- [Case 20: Executable documentation example](#case-20-executable-documentation-example)
- [Case 21: Generated and directive comments](#case-21-generated-and-directive-comments)
- [Case 22: Useful what/how comment](#case-22-useful-whathow-comment)

## Scoring rubric

Score each dimension from 0 to 2.

| Dimension | 0 | 1 | 2 |
|---|---|---|---|
| Semantic accuracy | Treats style as meaning or misunderstands behavior | Partly identifies the concept | Correctly models the concept, role, and distinction |
| Evidence and context | Judges an isolated name/comment or invents facts | Uses some context | Uses declarations, call sites, tests/contracts, explanations, and domain language as available |
| Decision quality | Defaults to rename/extract/comment deletion | Decision is plausible but weakly gated | Chooses a fitting design decision or explanation disposition with clear evidence |
| Proportionality | Produces churn, abstraction, or prose volume without value | Mostly proportional | Chooses the smallest coherent change and output |
| Boundary safety | Ignores contracts, contexts, consumers, or operational dependencies | Mentions risk generically | Identifies affected surfaces and a concrete migration strategy |
| Explanation integrity | Invents rationale/history, trusts prose blindly, or deletes important knowledge | Notices explanation concerns but incompletely verifies or places them | Treats prose as a claim, preserves supported rationale, and uses KEEP/ADD/REWRITE/REMOVE/RELOCATE/CONVERT/DEFER correctly |
| Actionability | Gives vague taste-based advice | Gives a candidate or general direction | Gives precise rationale, representative usage, placement, and safe next steps |

A passing result should score at least **11/14** and must not score 0 on semantic accuracy or boundary safety. For cases involving comments or documentation, it must not score 0 on explanation integrity.

Use the cases as regression tests, not as scripts. Equivalent recommendations may pass when they preserve the same semantic distinctions and safety constraints.

## Case 1: Framework-mandated role

**Prompt**

“`InventoryRepository` is generic. Rename it to something cleaner.” The interface follows the repository framework and exposes domain-specific inventory lookup and save operations.

**Expected behavior**

- Prefer **LEAVE** unless repository usage is misleading.
- Explain that `Repository` carries an established role and `Inventory` supplies the domain concept.
- Do not rename merely to remove a suffix.

**Failure signal**

Invents names such as `InventoryDataGatewayEngine` or insists every role name is noise.

## Case 2: Overloaded term across contexts

**Prompt**

“Both identity and marketing have a `Profile`. Should we share one model?” Identity stores credentials and legal identity; marketing stores preferences and segmentation.

**Expected behavior**

- Prefer separate bounded-context models.
- Identify different invariants, lifecycle, and ownership.
- Recommend explicit translation or shared identifiers only where justified.

**Failure signal**

Creates a universal `Profile` because duplicate names are considered inconsistent globally.

## Case 3: Public serialized field

**Prompt**

“Rename JSON field `ship_to` to `destination` everywhere.” External clients consume the field.

**Expected behavior**

- Treat the change as a high-risk contract migration, not a mechanical cleanup.
- Inspect versioning, aliases, dual-read/write, compatibility windows, generated docs, and client examples.
- The semantic recommendation may be **RENAME**, but implementation must be staged.

**Failure signal**

Performs an internal search-and-replace and claims completion.

## Case 4: Affix-heavy name

**Prompt**

“Review `DefaultCachedRemoteCustomerDataServiceImpl`.” It is the sole implementation of a typed `CustomerDirectory` interface; the module already says `crm/cache`.

**Expected behavior**

- Identify repeated implementation, storage, and module context.
- Consider a smaller role name such as `CachedCustomerDirectory` if it distinguishes a real decorator.
- Do not blindly strip `Cached` if caching changes contract or behavior.

**Failure signal**

Chooses the shortest word without checking role or suggests an even longer name.

## Case 5: Stringly typed concept

**Prompt**

“`String status` is passed through six methods and compared with `new`, `quoted`, `bought`, and `failed`.”

**Expected behavior**

- Prefer **INTRODUCE CONCEPT**, likely a state enum/sum type with domain-approved names.
- Inspect lifecycle transitions, unknown values, storage/API compatibility, and casing.
- Update tests, examples, serialized forms, and telemetry labels that encode the states.
- Avoid reducing this to renaming `status`.

**Failure signal**

Suggests `shipmentStatusString` only.

## Case 6: Line-count-only move

**Prompt**

“This function is 55 lines. What class should I extract it into?” The function is one coherent parser with local helpers and no duplicated policy.

**Expected behavior**

- Reject line count as sufficient evidence.
- Consider **LEAVE** or local **EXTRACT** only for nameable subrules that improve reading.
- Ask what changes independently or what decision needs hiding.

**Failure signal**

Creates a class based on size alone.

## Case 7: No findings

**Prompt**

Review a small module whose types, functions, tests, comments, and domain documentation use consistent terms and natural call sites.

**Expected behavior**

- Say the naming, explanations, and boundaries are sound.
- Use **LEAVE**, **KEEP**, and “Keep as-is” where applicable.
- Do not produce low-value synonyms or comments to appear useful.

**Failure signal**

Manufactures renames, extracts, or documentation changes with no semantic benefit.

## Case 8: Advice versus implementation

**Prompt A**

“Where should this policy live?”

**Expected behavior A**

- Analyze and recommend; do not edit files.

**Prompt B**

“Move this policy to the correct owner, update callers and documentation, and run tests.”

**Expected behavior B**

- Inspect code and contracts, implement a small safe change, update affected explanations, validate, and report results.

**Failure signal**

Edits on Prompt A or only recommends on Prompt B despite having tools and access.

## Case 9: Missing context

**Prompt**

“Is `resolve` a bad function name?” No code or domain is supplied.

**Expected behavior**

- Choose **DEFER** or provide a conditional answer.
- Explain that `resolve` can precisely name dependency, name, or cache resolution but may hide a more specific domain decision.
- Identify the evidence needed: receiver, inputs, output, side effects, failure behavior, and call site.

**Failure signal**

Declares the word universally bad.

## Case 10: Event migration

**Prompt**

“Rename `ShipmentUpdate` to `ShipmentDelivered`.” The event fires for label purchase, pickup, transit, delivery, and exception changes.

**Expected behavior**

- Reject the proposed rename because it lies about most events.
- Consider whether the broad event should remain, gain an explicit status transition, or split into facts based on consumer needs.
- Inspect schema, consumers, replay behavior, topic names, docs, and observability compatibility.

**Failure signal**

Accepts the user’s candidate without checking behavior.

## Case 11: Duplicate code with different meaning

**Prompt**

Billing and returns each calculate 10% using identical code. A reviewer proposes `PercentageUtils.tenPercent()`.

**Expected behavior**

- Do not merge by syntax alone.
- Determine whether one is tax and one is restocking policy; keep distinct domain rules if they change independently.
- Shared numeric machinery may be reused without sharing the policy name.

**Failure signal**

Creates a generic utility that erases domain meaning.

## Case 12: Wrong owner with decisive evidence

**Prompt**

A REST controller implements a regulated hazardous-material shipping rule. The same rule is duplicated in batch processing and a message consumer.

**Expected behavior**

- Choose **MOVE**, or **INTRODUCE CONCEPT** plus dependent move, even without waiting for another minor signal.
- Name the domain policy using established vocabulary.
- Keep adapters responsible only for transport concerns.
- Add focused tests and migrate all entry points and explanations.

**Failure signal**

Leaves the rule in each adapter or extracts a generic `ValidationUtil`.

## Case 13: Narrating inline comment

**Prompt**

```java
// Check whether the shipment is international.
if (!origin.equals(destination)) {
```

No tests or domain definition are shown.

**Expected behavior**

- Recognize syntax narration and consider **CONVERT** to a named predicate.
- Do not assume country inequality is the correct definition of “international” or customs eligibility.
- Choose **DEFER** for the exact code change until territorial and contract evidence is available.

**Failure signal**

Deletes the comment and introduces `isInternational()` while silently preserving an unverified rule.

## Case 14: Necessary vendor-rationale comment

**Prompt**

A concise comment explains that a carrier classifies Puerto Rico as international in one API but domestic in its customs contract. The code delegates to `customsPolicy.requiresDocuments`.

**Expected behavior**

- Prefer **KEEP** or a precision **REWRITE** after verifying the external contract.
- Explain that a good method name does not preserve the vendor mismatch or rejected shortcut.
- Suggest linking an authoritative contract or real issue if available.

**Failure signal**

Deletes the comment because “comments should only explain code that is unclear” or because the method name is self-documenting.

## Case 15: Comment and code disagree

**Prompt**

A comment says a purchase retries at most three times; code and tests use five; an operations guide also says three.

**Expected behavior**

- Use explanation **DEFER** and raise a potential correctness/contract conflict.
- Inspect idempotency, duplicate-purchase risk, configuration, incident history, and the authoritative policy.
- Do not assume the executable behavior is intended merely because tests cover it.

**Failure signal**

Automatically updates the comment to five or changes the code to three without evidence.

## Case 16: Vague TODO

**Prompt**

```typescript
// TODO: clean this up later
const code = legacyServiceCode(payload);
```

**Expected behavior**

- Choose **REWRITE**, **RELOCATE**, **REMOVE**, or **DEFER** based on available migration evidence.
- Require concrete unresolved work and an exit condition.
- Link a real issue when one exists, but never fabricate an issue ID, owner, date, or version.
- Avoid treating the word `legacy` as self-explanatory.

**Failure signal**

Rewrites it as `TODO(SHQ-1234)` without being given that issue or leaves equally vague prose.

## Case 17: Public doc comment repeats the signature

**Prompt**

```java
/** Gets the customer ID. */
CustomerId customerId();
```

The system has billing, storefront, and identity-provider customer identifiers.

**Expected behavior**

- Prefer **REWRITE** to document the identifier domain, or **INTRODUCE CONCEPT** if one type currently mixes identifiers.
- Follow ecosystem rules that may require exported/public documentation.
- Do not pad the comment with generic `@return` text.

**Failure signal**

Deletes all documentation because it restates the signature, or expands it without adding the critical distinction.

## Case 18: Architectural decision buried in code

**Prompt**

A method contains 40 lines about queue alternatives, organizational history, rollout decisions, and operational consequences.

**Expected behavior**

- Choose **RELOCATE** for the decision context to an ADR or equivalent decision record.
- Keep a concise local constraint or pointer only when needed for safe maintenance.
- Preserve status, alternatives, consequences, and supersession history in the durable record.
- Do not invent an ADR identifier.

**Failure signal**

Deletes the history as noise or keeps the entire essay beside one method.

## Case 19: Cross-surface vocabulary drift

**Prompt**

The domain type is `ShipmentQuote`, tests say “rate response,” an event is `RatesReady`, metrics use `quote_fetch`, and the UI says “shipping options.”

**Expected behavior**

- Perform a semantic-surface audit before bulk renaming.
- Determine which words are synonyms, lifecycle stages, different concepts, or intentional audience translations.
- Establish a canonical bounded-context term and explicit mappings.
- Include event consumers, metrics, dashboards, alerts, docs, tests, and UI impact.

**Failure signal**

Globally replaces every phrase with `ShipmentQuote`, including customer-facing language, without checking meaning or compatibility.

## Case 20: Executable documentation example

**Prompt**

A public Rust function’s example no longer compiles after an API rename, but normal unit tests pass.

**Expected behavior**

- Treat the example as part of the public semantic surface and **REWRITE** it.
- Run documentation tests when supported.
- Check whether the example encodes additional contract or edge-case expectations.
- Search related guides and sample projects for the old API name.

**Failure signal**

Ignores the example because production code compiles or converts it into non-executable pseudocode without reason.

## Case 21: Generated and directive comments

**Prompt**

A reviewer asks to remove “ugly comments” from a generated client, including a generated-file marker and a narrow linter suppression.

**Expected behavior**

- Identify machine-consumed and generated comments separately from ordinary prose.
- Edit the generator/template rather than generated output when a real change is needed.
- Preserve the generated marker and verify whether the suppression is still necessary and narrowly scoped.
- Respect license/attribution requirements.

**Failure signal**

Deletes directives or legal/generated markers as cosmetic clutter.

## Case 22: Useful what/how comment

**Prompt**

A parser includes a short diagram explaining a non-obvious binary frame layout and byte offsets. A reviewer says comments may only explain why.

**Expected behavior**

- Prefer **KEEP** if the diagram is accurate and adjacent to the parser it describes.
- Recognize expansion of “what/how” as valuable when the representation is intrinsically hard to infer.
- Suggest tests for boundary offsets and a protocol-spec link when available.
- Check drift when the protocol version changes.

**Failure signal**

Removes the diagram solely because it does not explain a business rationale.
