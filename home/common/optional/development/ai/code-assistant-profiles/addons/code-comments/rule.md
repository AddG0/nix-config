Comments say the *why*, never the *what*, and default to none: if a reader who
knows the language and its libraries could write the comment from the adjacent
code alone, it adds nothing. This holds as you write, not as a pass afterward.

Delete on the first match:

- Cosmetic — banner `===`, divider, `// end if`, closing-brace label.
- Commented-out or dead code. Version control remembers it.
- A change, author, date, or "as requested" — that belongs in the commit message.
- Meta-commentary on the edit: `// new`, `// changed per request`, `// previously X`.
- Restates the code, echoes the name, or narrates a standard language or library idiom.
- Justifies the choice instead of informing the reader — keep any real fact, cut the defence.
- A TODO with no ticket and no resolution condition.
- Floating above code it does not describe — move it onto that code, or drop it.
- Possibly stale because the surrounding code just changed — verify, then fix or delete.

Keep, one line each:

- **Why** — the non-obvious reason for this approach. `// insertion sort: input is nearly sorted and N < 50`
- **Warning** — a consequence a reader would not expect. `// Don't cache — this table is write-heavy`
- **Workaround** — an external quirk, with a reference. `// vendor API returns 1-based indices; see ACME-1234`
- **Domain rule** invisible in the code. `// clamp to 86°F — HVAC max`
- **Public-API doc** adding precision beyond the name and signature.
- **TODO** carrying a ticket and a resolution condition.

Compress rather than justify — a real *why* fits on one line. Prefer a better name
or an extracted function over a comment explaining *what*, but do not invent
`longCamelCaseNamesThatAreReallyComments`.

Doc comments: public and non-trivial only, first sentence is the summary, never
restate the type system. Tests: name the behavior, not the implementation
(`rejects login when password is expired`, not `testLogin`). File headers: a
one-line purpose is fine, never `@author`, date, or revision history.
