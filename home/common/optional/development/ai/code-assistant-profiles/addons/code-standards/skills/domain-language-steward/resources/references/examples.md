# Calibrating Examples

These examples demonstrate the reasoning and output style. Adapt names to the language and repository; do not copy them mechanically.

## Contents

- [1. Vague operation name](#1-vague-operation-name)
- [2. Broad service name](#2-broad-service-name)
- [3. Missing identifier concept](#3-missing-identifier-concept)
- [4. Domain policy in a controller](#4-domain-policy-in-a-controller)
- [5. Framework role that should remain](#5-framework-role-that-should-remain)
- [6. Command versus event](#6-command-versus-event)
- [7. Misleading getter](#7-misleading-getter)
- [8. Boundary models sharing one name](#8-boundary-models-sharing-one-name)
- [9. Hollow helper](#9-hollow-helper)
- [10. Same word across bounded contexts](#10-same-word-across-bounded-contexts)
- [11. Clear local name](#11-clear-local-name)
- [12. Narrating comment](#12-narrating-comment)
- [13. Essential rationale comment](#13-essential-rationale-comment)
- [14. Architectural rationale in a method](#14-architectural-rationale-in-a-method)
- [15. Weak TODO note](#15-weak-todo-note)
- [16. Cross-surface terminology drift](#16-cross-surface-terminology-drift)
- [17. Comment-code contradiction](#17-comment-code-contradiction)
- [18. Public documentation as contract](#18-public-documentation-as-contract)

## 1. Vague operation name

**Input**

```java
Quote processData(Data data)
```

The method validates a destination, requests carrier rates, removes ineligible rates, and returns the selected quote.

**Bad response**

Rename it to `processShippingData` because more descriptive names are better.

**Good response**

**Decision: DEFER**, then likely SPLIT or RENAME after inspecting callers and ownership.

`processData` hides several domain actions, but a synonym is not enough. Establish whether this method is an application use case such as `quoteShipment`, an orchestration method such as `fetchEligibleRates`, or an improperly combined workflow. Inspect the type hidden behind `Data`, side effects, selection policy, and call sites. Do not encode every step into a giant name.

## 2. Broad service name

**Input**

`OrderService` has 35 methods.

**Bad response**

Split it because services should be small and 35 methods is too many.

**Good response**

**Decision: DEFER** until responsibilities and change signals are mapped.

Method count is not a semantic boundary. Group methods by domain vocabulary, dependencies, invariants, callers, and reasons to change. If purchasing, cancellation, fulfillment, and reporting use distinct policies and change independently, propose named capabilities such as `OrderCancellationPolicy` or `FulfillmentCoordinator`. If the type is a coherent application facade, LEAVE may be correct even with many methods.

## 3. Missing identifier concept

**Input**

```rust
fn load_rate(carrier_id: String, service_id: String) -> Rate
```

Both identifiers are repeatedly validated and are easy to swap.

**Good response**

**Decision: INTRODUCE CONCEPT**

```rust
struct CarrierId(String);
struct CarrierServiceId(String);

fn load_rate(carrier_id: CarrierId, service_id: CarrierServiceId) -> Rate
```

The benefit is not shorter syntax. The types preserve two domain distinctions, centralize validation, and prevent accidental interchange. Check serialization and database adapters before implementation.

## 4. Domain policy in a controller

**Input**

A GraphQL resolver contains 40 lines deciding whether a shipment can use a carrier based on destination, account status, service restrictions, and hazardous-material rules.

**Good response**

**Decision: MOVE** the decision to a domain policy such as `ShipmentEligibilityPolicy`; keep request parsing and response mapping in the resolver.

Evidence includes a nameable domain question, several invariants, and boundary leakage. The resolver should orchestrate; it should not own carrier eligibility. A representative call site might become:

```java
if (!shipmentEligibility.canUse(carrier, shipment, destination)) {
    return ineligibleResponse();
}
```

Confirm whether “eligibility”, “availability”, or “serviceability” is the canonical domain term before fixing the exact name.

## 5. Framework role that should remain

**Input**

A Spring class named `ShippingCacheResolver` implements the framework’s `CacheResolver` interface and only selects one of three caches from request metadata.

**Good response**

**Decision: LEAVE** unless the selection rules are business policy.

`Resolver` is not empty noise here; it names the exact framework role, and `Shipping` supplies context. If the implementation later embeds quote-lifetime or customer-tier rules, EXTRACT a domain-specific `ShippingQuoteCachePolicy` while retaining the resolver as the framework adapter.

## 6. Command versus event

**Input**

`CreateLabelEvent` is published after a carrier label has been successfully purchased.

**Good response**

**Decision: RENAME** to `LabelCreated` or the domain’s more precise outcome, such as `LabelPurchased`.

An event reports a fact and should use past tense. `CreateLabel` is suitable for a command requesting action. Check topic names, schema identifiers, consumers, and replay compatibility; this may require versioning or dual publishing rather than a mechanical rename.

## 7. Misleading getter

**Input**

```typescript
async getCustomer(id: CustomerId): Promise<Customer> {
  const payload = await crm.fetchCustomer(id);
  await cache.put(id, payload);
  return mapCustomer(payload);
}
```

**Good response**

**Decision: RENAME** if the operation is intentionally responsible for remote loading and caching.

Candidates depend on contract:

- `loadCustomer` if absence is exceptional and remote I/O is expected
- `fetchCustomer` if the remote retrieval is the important semantic
- `findCustomer` if absence is represented normally

Do not choose among these without checking failure and absence behavior. The current `get` understates I/O and side effects.

## 8. Boundary models sharing one name

**Input**

The same module imports a domain `Order`, an ORM `Order`, and a vendor SDK `Order`, with aliases such as `Order2` and `OrderModel`.

**Good response**

**Decision: RENAME boundary representations**, not the domain concept.

Use role-bearing names such as `Order`, `OrderRecord`, and `ShopifyOrderPayload`, with explicit translators. This makes representation boundaries visible and removes arbitrary numeric aliases. Verify whether the repository already uses `Entity`, `Row`, `Document`, `Dto`, or another established suffix.

## 9. Hollow helper

**Input**

```java
void purchaseLabel(Order order) {
    validate(order);
    purchaseValidatedLabel(order);
}

void purchaseValidatedLabel(Order order) {
    carrier.purchase(order);
}
```

The second method is private, used once, and adds no policy, error translation, or reusable concept.

**Good response**

**Decision: MERGE / INLINE** `purchaseValidatedLabel` unless it is the planned seam for meaningful carrier behavior.

The helper disperses one operation and forces navigation without hiding volatility or naming a domain rule. Keep `validate` extracted only if it expresses a coherent validation concept. One-use alone is not the reason; semantic emptiness is.

## 10. Same word across bounded contexts

**Input**

Billing treats `Customer` as the legally invoiced organization. Support treats `Customer` as the person opening a ticket. A reviewer proposes one shared enterprise `Customer` model.

**Good response**

**Decision: LEAVE separate models** and make context translation explicit.

The shared everyday word does not imply shared identity, lifecycle, or invariants. Use context-qualified modules or types when they meet, such as `billing.Customer` and `support.Customer`. A universal model would erase useful differences and increase coupling.

## 11. Clear local name

**Input**

```java
var eligibleRates = rates.stream()
    .filter(eligibility::allows)
    .toList();
```

A reviewer suggests `allShippingRatesThatAreEligibleForTheCurrentShipment`.

**Good response**

**Decision: LEAVE** `eligibleRates`.

The type, method scope, and predicate supply the omitted context. The longer alternative repeats information and makes the code harder to scan. No change is warranted.


## 12. Narrating comment

**Input**

```java
// Check whether the shipment is international.
if (!shipment.originCountry().equals(shipment.destinationCountry())) {
    requestCustomsDocuments();
}
```

**Good response**

**Explanation disposition: CONVERT**, with a possible **EXTRACT** or **INTRODUCE CONCEPT** decision after checking the domain rule.

A predicate such as `shipment.isInternational()` would communicate the immediate decision better than narrating the comparison. However, do not assume country inequality is the true customs rule. Inspect tests, territories, carrier contracts, and whether “international” or “requires customs documents” is the actual concept. Remove the comment only after the code expresses the verified rule.

## 13. Essential rationale comment

**Input**

```java
// Carrier X reports Puerto Rico under its international region codes, but its
// customs contract treats these shipments as domestic. Do not derive customs
// requirements directly from the carrier region response.
return customsPolicy.requiresDocuments(shipment);
```

**Good response**

**Explanation disposition: KEEP** or **REWRITE** for precision.

The code communicates which policy answers the question, but it cannot preserve the external-system mismatch or why the apparently simpler region check is unsafe. Verify the carrier contract or tracked issue and link it when available. Do not delete the comment merely because the method name is clear.

## 14. Architectural rationale in a method

**Input**

A method contains a 40-line comment recounting a queue technology decision, rejected alternatives, rollout history, and operational consequences.

**Good response**

**Explanation disposition: RELOCATE** most of the content to an architecture decision record.

Keep a concise local note only if a current constraint affects how the method may be changed, for example: “Publishing must remain transactional with the outbox; see ADR-017.” Do not invent an ADR identifier. The full decision context belongs where alternatives, consequences, status, and supersession can be maintained.

## 15. Weak TODO note

**Input**

```typescript
// TODO: clean this up later
const code = legacyServiceCode(payload);
```

**Good response**

**Explanation disposition: REWRITE, RELOCATE, or REMOVE** depending on evidence.

Search for the migration or issue that makes the code temporary. A useful replacement names the unresolved work and removal condition, such as removing the translation after persisted configurations have migrated to canonical service codes. Link a real issue when one exists; never fabricate an issue ID, owner, deadline, or version. If there is no concrete work or condition, the TODO adds no actionable knowledge.

## 16. Cross-surface terminology drift

**Input**

The domain type is `ShipmentQuote`, tests call it a “rate response,” an event is `RatesReady`, metrics use `quote_fetch`, and the UI says “shipping options.”

**Good response**

**Decision: DEFER** any broad rename until the concepts and audiences are mapped, then perform a **semantic-surface audit**.

Determine whether “quote,” “rate,” and “shipping option” are synonyms, lifecycle stages, or intentional audience translations. Establish a canonical term within the bounded context and preserve explicit translations where useful. Inspect schemas, consumers, dashboards, alerts, saved queries, docs, and UI copy. Do not bulk-replace “shipping options” in the product if it is intentionally clearer for customers.

## 17. Comment-code contradiction

**Input**

```java
// Retry at most three times to avoid duplicate carrier purchases.
return retryPolicy.execute(5, carrier::purchaseLabel);
```

Tests assert five attempts, but an operations guide says three.

**Good response**

**Explanation disposition: DEFER** and raise the contradiction as a correctness finding.

Do not simply update the comment to five or change the code to three. Identify the authoritative retry/idempotency contract, inspect duplicate-purchase protection and incident history, and determine whether the code, test, comment, or guide is wrong. The conflicting explanations may expose a production bug.

## 18. Public documentation as contract

**Input**

```rust
/// Gets a quote.
pub fn quote(shipment: &Shipment) -> Result<Quote, QuoteError>
```

The function performs remote I/O, may return a cached estimate, and rejects destinations whose postal code has not been normalized.

**Good response**

**Explanation disposition: REWRITE** the public documentation; consider **RENAME** only if `quote` is not the established operation.

Document the caller-relevant contract: remote/cached behavior if observable, postal-code precondition, failure categories, and whether the result is an estimate. Do not narrate the implementation or repeat the signature. Add an executable example when the ecosystem supports documentation tests and the setup can remain deterministic.
