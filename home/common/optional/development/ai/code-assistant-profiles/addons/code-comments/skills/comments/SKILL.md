---
name: comments
description: This skill should be used when writing, editing, or reviewing code comments, docstrings, or doc comments (Javadoc, JSDoc/TSDoc, PHPDoc, Go/Rust doc comments), and when naming tests. It enforces restraint — it deletes comments that restate the code, narrate language/library idioms, justify a choice, or record a change, and keeps only the non-obvious *why*. Run it as a final pass over every code change to prune the comments just written.
---

# Comments

**Write the *why*, never the *what*. When in doubt, write no comment.**
A comment earns its place only by saying something the code cannot — intent,
a trade-off, a constraint, or a warning. Default to fewer.

Coding agents over-comment by default. The fix is not "no comments" — it is
**deletion plus targeting**: cut the noise, keep the rare line that informs a
reader the code already can't.

## Mandatory final pass

After writing or editing code, **re-read every comment just added** and run each
one through the decision tree below. Delete on the first matching DELETE rule.
This pass is not optional — it is the point of the skill.

## The one test

> If a reader who knows this language and its libraries could write the identical
> comment just from the adjacent code, the comment adds nothing. Delete it.

## Decision tree (apply to every comment)

```
Cosmetic (banner ===, divider, `// end if`, closing-brace label)? → DELETE
Commented-out / dead code?                                        → DELETE (VCS remembers)
Records a change / author / date / "as requested"?               → DELETE → put it in the commit message
Restates the code or echoes the name?                            → DELETE
Narrates a standard language/library idiom?                      → DELETE
Justifies the choice instead of informing the reader?            → DELETE the justification, keep any real fact
TODO without a tracking link or clear resolution?                → DELETE or convert to a ticket
Not sitting on the code it describes?                            → MOVE onto that code, or DELETE
Possibly stale (surrounding code just changed)?                  → VERIFY, then fix or DELETE
Explains WHY — intent, trade-off, business/domain rule, workaround? → KEEP (one line)
Warns of a non-obvious consequence (ordering, side effect)?        → KEEP
Public-API doc adding precision beyond the name/signature?         → KEEP
Otherwise (explains the WHAT of already-clear code)                → DELETE
```

## Delete this → write this instead

| Instead of… | Write… |
|---|---|
| `i += 1  // increment i` | nothing |
| `// loop through users` above `for u in users:` | nothing |
| `/** Gets the name. */ getName()` | nothing — drop the docblock |
| `// fixed bug` / `// added by agent` / `// as requested` | nothing — it goes in the commit message |
| a commented-out block kept "just in case" | nothing — delete it; VCS remembers |
| `// TODO: fix later` | `// TODO(PROJ-123): handle null tenant` or nothing |
| a paragraph re-deriving what the code plainly does | the one non-obvious *why*, in one line |

**The agent trap:** never write meta-commentary about the edit itself
(`// new`, `// changed per request`, `// previously X`). That is commit-message
content, never source.

## Three rules that catch the subtle cases

These are the failures that survive a naive "why not what" pass.

### 1. Assume the reader knows the language and its libraries

Do not narrate idioms. Forwarding an `AbortSignal`, mapping over an array, or
awaiting a promise needs no explanation.

```js
// BAD — explains what the library already documents
// Forwarding the AbortSignal lets an unmount/refetch cancel the in-flight
// request, not just discard its result.
queryFn: async ({ signal }) => client.search({ signal }),

// GOOD — the idiom speaks for itself
queryFn: async ({ signal }) => client.search({ signal }),
```

### 2. Compress, don't justify — one line per *why*

Keep the single non-obvious fact. Cut words that defend the choice
("intentional rather than inherited", "explicitly set so that…"). A real *why*
fits on one line.

```js
// BAD — three lines, mostly self-justification + restatement
// Set staleTime explicitly (the agent set rarely changes) so the cadence is
// intentional rather than inherited; invalidate ASSISTANTS_QUERY_KEY to
// refresh after agent CRUD.
staleTime: 5 * 60_000,

// GOOD — the one fact the code can't say, in one line
staleTime: 5 * 60_000, // agent set rarely changes; invalidate the key after agent CRUD
```

### 3. A comment sits on the code it describes

Put each comment directly above (or trailing) the line it explains — never floated
above unrelated code, where it reads against the wrong lines and goes stale.

## Keep — comments that earn their place

Each is one line unless a caller genuinely needs more.

- **Why / intent** — the non-obvious reason for *this* approach or boundary.
  `// insertion sort: input is nearly sorted and N < 50`
- **Warning** — a consequence a reader would not expect.
  `// Don't cache — this table is write-heavy`
- **Workaround** — an external quirk, with a reference.
  `// vendor API returns 1-based indices; see ACME-1234`
- **Business / domain rule** invisible in the code. `// clamp to 86°F — HVAC max`
- **Public-API doc** — params, return shape, exceptions a caller must handle,
  when these add precision beyond the name.
- **Tracked TODO** — with a ticket link and a resolution condition.

## Prefer a better name over a comment

When tempted to explain *what* code does, first rename or extract so the comment
becomes unnecessary. Comment only when the rationale needs words a name cannot
carry. Do not invent `longCamelCaseNamesThatAreReallyComments` — write a short
comment instead.

## Doc comments, tests, and headers (essentials)

- **Doc comments:** public + non-trivial → document; private or self-evident →
  skip. The first sentence is the indexed summary. Never restate the type system
  (omit `@param`/`@return` types in TypeScript, Rust, typed PHP). Doc comment =
  for callers; line comment = for maintainers.
- **Tests:** name the **behavior**, not the implementation — a failing name
  should read like the broken scenario (`rejects login when password is expired`,
  not `testLogin`). Separate Arrange/Act/Assert with blank lines, not
  `// Arrange` markers.
- **File headers:** a one-line purpose is fine; never add `@author`, date, or
  revision-history headers — version control owns that and they rot immediately.

## References

- [`references/examples.md`](references/examples.md) — fuller before→after gallery
  across languages.
- [`references/doc-comments.md`](references/doc-comments.md) — per-language doc-comment format and when warranted.
- [`references/test-naming.md`](references/test-naming.md) — per-framework test-naming conventions.
