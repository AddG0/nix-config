# Before → after gallery

Worked examples of the deletions and rewrites the skill calls for. Each shows the
over-commented input, the corrected output, and the rule it exercises.

## Restating the code

```python
# BAD
total = 0
for item in cart:        # loop over the cart
    total += item.price  # add the price to the total

# GOOD
total = sum(item.price for item in cart)
```
Rule: restatement → delete. Renaming/extracting removed the need entirely.

## Narrating a library idiom

```ts
// BAD — explains what await/Promise.all already mean
// Wait for all requests to finish in parallel before continuing.
const results = await Promise.all(requests);

// GOOD
const results = await Promise.all(requests);
```
Rule: assume the reader knows the language/library → delete idiom narration.

## Compress, don't justify

```java
// BAD — defends the choice and restates the call
// We use a LinkedHashMap here instead of a HashMap because we want to
// preserve insertion order, which is important and intentional.
Map<String, Config> configs = new LinkedHashMap<>();

// GOOD — the one non-obvious fact, on one line
// LinkedHashMap: callers rely on insertion order
Map<String, Config> configs = new LinkedHashMap<>();
```
Rule: keep the real *why* in one line; cut self-justification.

## Misplaced comment

```go
// BAD — comment floats above unrelated code
// retries use exponential backoff
timeout := 30 * time.Second
client := newClient(timeout)
result, err := doWithRetry(client)

// GOOD — comment sits on the code it describes
timeout := 30 * time.Second
client := newClient(timeout)
result, err := doWithRetry(client) // exponential backoff between attempts
```
Rule: a comment belongs on the line it explains, or it gets deleted.

## A genuine why worth keeping

```python
# KEEP — the value and the reason are both invisible in the code
# 86°F is the hardware max; the thermostat firmware faults above it.
target = min(requested, 86)
```
Rule: domain rule the code can't express → keep, one line.

## Workaround with a reference

```js
// KEEP — external quirk a reader would otherwise "fix" and break
// Stripe returns amounts in cents; the dashboard expects dollars. See FIN-412.
const dollars = charge.amount / 100;
```
Rule: workaround for an external system → keep, with a ticket reference.

## Changelog / meta comment

```php
// BAD
// Updated 2026-06-22 by agent: switched to strict comparison as requested
if ($status === 'paid') { ... }

// GOOD — the history lives in the commit; the code stands alone
if ($status === 'paid') { ... }
```
Rule: records a change/author/date → delete; it belongs in the commit message.

## Mandated docblock that only echoes the signature

```ts
// BAD — restates name and types TypeScript already encodes
/**
 * Gets the user by id.
 * @param {string} id - the id
 * @returns {User} the user
 */
function getUser(id: string): User { ... }

// GOOD — nothing to add beyond the signature
function getUser(id: string): User { ... }
```
Rule: doc comment adding no precision beyond the signature → delete.
