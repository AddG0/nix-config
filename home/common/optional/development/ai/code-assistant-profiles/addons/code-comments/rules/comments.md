Default to none, and cap what survives at one line. A comment earns its place only
by saying what the adjacent code cannot — the non-obvious *why*. Needing a second
line means you are justifying the choice instead of informing the reader: keep the
fact, cut the defence. This holds as you write, not as a pass afterward.

```nix
# BAD — justifies the choice
# t3code runs `zsh -ilc` at startup so the whole .zshrc runs; both units are
# WantedBy=default.target, so without this they race and the secrets are missing.
After = ["sops-nix.service"];

# GOOD — the one fact the code cannot say
# t3code hydrates PATH with `zsh -ilc`, so startup cats the sops secrets.
After = ["sops-nix.service"];
```

Keep, one line each: **why** (`// insertion sort: input is nearly sorted, N < 50`),
**warning** (`// Don't cache — this table is write-heavy`), **workaround** with a
reference (`// vendor API returns 1-based indices; see ACME-1234`), **domain rule**
(`// clamp to 86°F — HVAC max`), **TODO** carrying a ticket and a resolution
condition, and public-API docs adding precision beyond the name and signature.

Delete the rest: restating the code or narrating a standard idiom; commented-out
code; banners, dividers, `// end if`; meta-commentary on the edit (`// new`,
`// changed per request`); a change, author, or date, which belong in the commit
message; a comment floating above code it does not describe; anything the
surrounding change may have left stale.

Prefer a better name or an extracted function over explaining *what*, without
inventing `longCamelCaseNamesThatAreReallyComments`. Doc comments: public and
non-trivial only, first sentence the summary, never restating the type system.
Tests name the behavior (`rejects login when password is expired`, not `testLogin`).
File headers: a one-line purpose, never `@author`, date, or revision history.
