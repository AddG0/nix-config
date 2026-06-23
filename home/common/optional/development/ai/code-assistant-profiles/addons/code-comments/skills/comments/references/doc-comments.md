# Doc comments by language

Cross-cutting rules (apply everywhere):

1. **Public + non-trivial → document. Private or self-evident → don't.**
2. **First sentence/summary is special** — it is what doc tooling indexes.
3. **Trivial members are the universal exception** — no docblock on `getFoo()`
   when there is "really and truly" nothing to say but "the foo".
4. **Never restate the type system** — omit redundant type annotations the
   signature already carries.
5. **Implementation detail belongs in body comments, not doc comments.**

## Java — Javadoc

- Summary is a **fragment**, not a sentence: `/** Returns the customer ID. */`
  not `/** This method returns the customer ID. */`.
- `@param` / `@return` / `@throws` must never appear with empty descriptions —
  if you have nothing to say, omit the tag.
- Document every visible class/member **except** simple, obvious ones (a plain
  getter with nothing else worthwhile to say).

```java
// BAD — restates name + signature, empty value
/** Gets the name. @return the name */
public String getName() { return name; }

// GOOD — no docblock; the name says it all
public String getName() { return name; }
```

## Python — docstrings (PEP 257)

- **Imperative mood:** `"""Return the active user."""` — prescribe the effect as
  a command, not `"""Returns the..."""`.
- One-liner must not be a signature restatement of the parameters.
- Public modules/classes/functions/methods get docstrings. Non-public members
  need at most a `#` comment, not a docstring.
- Google style: docstring is mandatory only when the API is public, the function
  is nontrivial in size, or the logic is non-obvious.
- Sections: `Args:`, `Returns:`, `Raises:`.

## JavaScript — JSDoc

- `@param {Type} name - Description`, `@returns`, `@throws`, `@example`.
- Descriptions (but not types) may be omitted when obvious from the signature.

## TypeScript — TSDoc / Google TS

- **Headline rule:** `/** JSDoc */` is for documentation a *user of the code*
  reads; `// line comments` are for implementation notes.
- **Do not declare types** in `@param`/`@return` — TS already encodes them, and
  duplicated types drift out of sync.
- TSDoc uses a hyphen and no brace-types: `@param x - The first input`.

## Go — doc comments

- **Must begin with the name** of the thing: `// Read reads up to len(b) bytes…`
  (tooling relies on this for search/indexing).
- Complete sentences; use "reports whether" for booleans.
- Package comment starts with `Package ` and lives in **one** file (convention:
  `doc.go`) for multi-file packages.
- No tags — prose only. Don't explain the current algorithm in a doc comment.

## Rust — rustdoc

- `///` documents the item below; `//!` documents the containing crate/module.
- First line before a blank line is the summary. Sections: `# Examples`,
  `# Panics`, `# Errors`, and `# Safety` (required for every `unsafe fn`).
- Don't write types into prose — rustdoc hyperlinks them.
- Public items should carry a runnable example showing *why*, using `?` not
  `unwrap()`.

## PHP — PHPDoc

- Three parts: summary, optional description, tags. The description is optional
  for straightforward elements.
- In typed PHP 8+, add `@param`/`@return` only when the description says
  something beyond the type.
