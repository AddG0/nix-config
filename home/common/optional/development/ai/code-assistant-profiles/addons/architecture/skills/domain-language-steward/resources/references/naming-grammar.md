# Naming Grammar

Use this reference after deciding what the code means. Preserve the target language and repository conventions for casing, acronyms, visibility, and idioms.

## Contents

- [General construction](#general-construction)
- [Values and types](#values-and-types)
- [Functions and methods](#functions-and-methods)
- [Booleans and predicates](#booleans-and-predicates)
- [Commands, events, and states](#commands-events-and-states)
- [Collections and quantities](#collections-and-quantities)
- [Identifiers, units, money, and time](#identifiers-units-money-and-time)
- [Boundary representations](#boundary-representations)
- [Architectural roles](#architectural-roles)
- [Modules and packages](#modules-and-packages)
- [Errors and tests](#errors-and-tests)
- [Abbreviations, length, and scope](#abbreviations-length-and-scope)
- [Warning terms](#warning-terms)

## General construction

Construct names from meaning outward:

1. Select the concepts the reader needs.
2. Choose canonical words for those concepts.
3. Arrange them according to the artifact’s grammatical role.
4. Remove words already made obvious by type, receiver, namespace, or immediate scope.
5. Read the declaration and representative call sites aloud.

Prefer semantic distinctions over thesaurus variation. `Shipment`, `Package`, `Parcel`, `Consignment`, and `Order` are not interchangeable unless the domain says they are.

A name should not promise more than the implementation. Avoid `validate`, `ensure`, `save`, `get`, `sync`, `complete`, `secure`, or `atomic` when the behavior only performs part of that promise.

## Values and types

- Name a value with a noun phrase: `destination`, `selectedRate`, `retryDeadline`.
- Name a type with a singular domain concept: `Shipment`, `CarrierAccount`, `Money`, `RetryPolicy`.
- Name a value object for the concept it protects, not its primitive representation: `CarrierId`, not `CarrierIdString`.
- Use role distinctions when two values share a type but not meaning: `originPostalCode` and `destinationPostalCode`.
- Avoid suffixing every type with `Data`, `Info`, `Object`, `Model`, or `Entity`. Add a suffix only when it distinguishes a real representation or role.
- Use `Request`, `Command`, `Query`, `Result`, `Snapshot`, `Record`, `Payload`, or `View` only when the artifact actually serves that role.

### Parameter clusters

When several parameters always travel together, ask whether they form a concept:

```text
countryCode, postalCode, region
```

may be an `Address` or `Destination`, but only if the domain treats the cluster as such. Do not create a parameter object solely to shorten a signature.

## Functions and methods

Name operations with verbs that reveal semantics and side effects.

| Semantic kind | Typical form | Example |
|---|---|---|
| Pure calculation | Domain verb or derived noun | `calculateShippingCharge`, `estimatedDeliveryDate` |
| Query that may be absent | `find`, `lookup`, language idiom | `findCarrierAccount` |
| Required retrieval | `load`, `require`, repository idiom | `loadOrder` |
| Conversion | `to`, `from`, `parse`, `decode`, `map` | `toCarrierRequest`, `parseTrackingNumber` |
| Mutation | Imperative domain verb | `selectRate`, `cancelShipment` |
| Validation returning violations | `validate` or domain-specific phrase | `validateDestination` |
| Enforcement that can fail | `require`, `ensure`, domain action | `requireActiveAccount` |
| I/O orchestration | Honest I/O verb | `fetchRates`, `persistAudit`, `publishLabelCreated` |

Do not use `get` for a function that performs expensive I/O, creates a value, mutates state, or has surprising failure behavior unless that is the established language idiom and call sites remain clear.

Avoid implementation verbs such as `process`, `handle`, `do`, `run`, or `execute` when a domain action is available. They can be correct at generic framework boundaries, such as a command handler interface.

A function named with `and` may contain more than one responsibility. Inspect before splitting; a single domain action can legitimately require several coordinated steps.

## Booleans and predicates

Make booleans read as claims or questions.

- Prefer positive predicates: `isEligible`, `hasTracking`, `canShip`, `shouldRetry`.
- Avoid double negatives: `!isNotEligible`.
- Distinguish capability, state, possession, policy, and instruction:
  - `canShip` — capability or permission
  - `isShipped` — current state
  - `hasShipment` — possession/existence
  - `shouldShip` — policy/decision
  - `shipNow` — command/input, often not suitable as a bare boolean
- Name the domain meaning, not the storage encoding: `isResidential`, not `residentialFlag`.
- Replace multiple interacting booleans with a state, mode, options type, or policy when invalid combinations exist.

For collection predicates, distinguish `any`, `all`, and existence precisely: `hasFailedShipments`, `allRatesExpired`.

## Commands, events, and states

- Name commands in the imperative because they request action: `CreateLabel`, `CancelShipment`, `RefreshRates`.
- Name events in the past tense because they report a fact: `LabelCreated`, `ShipmentCancelled`, `RatesExpired`.
- Name queries as questions or requested results: `GetShipmentStatus`, `FindEligibleRates`.
- Name states as nouns/adjectives, not actions: `Pending`, `InTransit`, `Delivered`.
- Distinguish intent from outcome. `CreateLabelEvent` is ambiguous if it is emitted after creation; prefer `LabelCreated` for the fact.
- Include context in event names only when needed to avoid collision or clarify ownership. Do not stuff producer, transport, version, and payload type into every domain event name.

## Collections and quantities

- Use a plural or domain collection noun: `rates`, `eligibleRates`, `manifest`.
- Do not encode the container implementation unless callers need that fact: prefer `rates` over `rateList` in most typed code.
- Distinguish filtered subsets: `eligibleRates`, `purchasedLabels`, `unmatchedShipments`.
- Name counts and totals explicitly: `shipmentCount`, `totalWeight`, `remainingAttempts`.
- Avoid `items` when the elements have a domain name.

## Identifiers, units, money, and time

- Distinguish identifiers with their concept: `orderId`, `carrierAccountId`, `requestId`.
- Introduce domain identifier types when IDs from different concepts share a primitive and accidental mixing is plausible.
- State units in the name when the type does not: `timeoutMillis`, `weightGrams`, `distanceMiles`.
- Prefer unit-bearing types when available: `Duration`, `Weight`, `Money`.
- Distinguish amount from currency and gross/net/tax meanings: `shippingCharge`, `taxAmount`, `total`, `currency`.
- Make time semantics explicit: `createdAt`, `expiresAt`, `deliveryDate`, `processingDuration`, `retryAfter`.
- Distinguish wall-clock instants, local dates, durations, and deadlines.
- Avoid `timestamp` when the business meaning is known.

## Boundary representations

Do not give every representation the same unqualified type name when they can appear together.

| Layer/context | Example name | Meaning |
|---|---|---|
| Domain | `Order` | Domain model and invariants |
| HTTP/RPC input | `CreateOrderRequest` | Boundary request contract |
| Vendor integration | `ShopifyOrderPayload` | External representation |
| Persistence | `OrderRecord` or repository-specific entity | Stored representation |
| Read model | `OrderSummary` | Query-oriented projection |
| Output | `OrderResponse` | Boundary response contract |

Use the repository’s established suffixes only when they identify real roles. Keep translation functions explicit, such as `toDomain`, `toRecord`, or `toCarrierRequest`; use more specific verbs when conversion can lose information or perform validation.

## Architectural roles

Role names are useful when they describe a real responsibility. Qualify the role with the domain concept it serves.

- `ShippingRateRepository`
- `LabelPurchaseController`
- `CarrierAccountResolver`
- `ShipmentEligibilityPolicy`
- `ShopifyOrderAdapter`
- `TrackingNumberParser`

Do not replace a precise framework role simply to eliminate a suffix. `CacheResolver` may be the exact Spring/framework concept. Rename or extract only if the implementation also contains a separate domain policy, such as `ShippingQuoteCachePolicy`.

Watch for role inflation:

- `Manager`, `Service`, `Processor`, and `Engine` often hide the actual responsibility.
- `Helper`, `Util`, and `Common` often hide absent ownership.
- `Base` can hide accidental inheritance or an unspecified abstraction.

These names are evidence prompts, not verdicts. Inspect methods, dependencies, change history, and callers.

## Modules and packages

- Name modules for the capability or model they own, not a miscellaneous technical category.
- Prefer context-rich packages such as `shipping/rates`, `billing/invoices`, or `identity/sessions` when they match the system’s architecture.
- Technical-layer packages can be appropriate inside a bounded context; do not reorganize a whole codebase without evidence.
- Avoid `misc`, `common`, `shared`, and `utils` unless the contents truly share a stable purpose. A broadly reused package should have a stronger, nameable contract.
- A module name should make likely contents unsurprising and non-members obvious.

## Errors and tests

### Errors

- Name an error for the failed domain condition: `UnsupportedDestination`, `CarrierAccountInactive`, `RateExpired`.
- Avoid restating `Error` when the language convention already supplies it, unless required by the repository.
- Distinguish a domain rejection from transport, timeout, persistence, and programmer errors.
- Include operation context in messages, not necessarily in every error type name.

### Tests

- Name tests for behavior and condition, not implementation steps.
- A useful pattern is `[behavior] when [condition]`, adapted to the language/framework.
- Prefer `selects_cheapest_eligible_rate` over `test_rate_service_method_2`.
- Let tests reinforce the same domain vocabulary used by production code.

## Abbreviations, length, and scope

- Use abbreviations that the team and domain treat as words (`HTTP`, `SKU`, `ETA`) according to repository casing conventions.
- Avoid private abbreviations that save characters but cost interpretation.
- Keep common operations short when type, receiver, and module context make them obvious.
- Use more description when scope is wider, nearby concepts are confusable, or the type system does not carry meaning.
- Local names can be concise when their lifetime and role are immediately visible.
- Do not enforce “longer is better.” A long name that repeats its namespace, receiver, type, and return type is noise.
- Do not enforce “shorter is cleaner.” Omitted distinctions create ambiguity.

Compare names at representative call sites:

```text
order.cancel(reason)
policy.canShip(order, destination)
repository.findByTrackingNumber(number)
```

A declaration-only name can look good while producing awkward or misleading usage.

## Warning terms

When these appear, ask the corresponding question:

| Term | Question |
|---|---|
| `data`, `info`, `object`, `item`, `thing` | What domain concept is actually represented? |
| `process`, `handle`, `execute`, `do` | What domain action or decision occurs? |
| `manager`, `service`, `engine`, `processor` | Is there one responsibility or several unrelated ones? |
| `helper`, `util`, `common`, `shared` | Who semantically owns this behavior? |
| `base`, `abstract` | What stable abstraction or contract is shared? |
| `impl`, `default` | Does this distinguish a real implementation choice, or repeat what the type system and module already show? |
| `type`, `kind`, `mode`, `flag` | Is this a state, strategy, policy, or sum type? |
| `temp`, `new`, `old`, `final` | What lifecycle or role distinction is intended? |
| `payload`, `record`, `response`, `request` | Is this a genuine boundary representation or a suffix added by habit? |

Retain the term when the answer confirms it is precise in context.
