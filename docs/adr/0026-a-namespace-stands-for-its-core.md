---
status: accepted
date: 2026-11-23
---

# A namespace stands for its core, and its leaves bring it along

Extends ADR 0012: the same import expansion now also resolves cores.

## Context and Problem Statement

Several optional namespaces hold a `core` module next to add-ons that only make
sense on top of it: `browsers.zen.core` with `browsers.zen.steamdb`,
`media.core`, `gaming.core`, `development.core`, `development.ai.core`. Nothing
tied them together. `steamdb` only sets Zen spaces and pins, so a host that
imported it without `zen.core` got a space on a browser that was never enabled,
silently. A sweep found five home files importing media or development add-ons
without their core.

Writing `(with optional.primary.browsers.zen; [steamdb])` already names
`browsers.zen`; the import should mean Zen, not just one file under it.

## Considered Options

1. Expand imports where ADR 0012 already does (host files, user `common/core`,
   suite halves): a namespace attrset with a `core` is replaced by that core,
   and every leaf brings the `core` of its own namespace, from the shared tree
   and the user's tree.
2. Option 1, but a leaf brings the core of every enclosing namespace.
3. Each add-on imports its namespace's core itself.
4. Make namespaces with a core callable (`__functor`), so they import as their
   core anywhere, not only in expanded lists.
5. Keep cores explicit and add a check that fails a host importing an add-on
   without its core.

## Decision Outcome

Chosen: option 1.

- Option 2 rejected: any `development.ai.*` add-on would drag in
  `development.core`, which installs Chromium and dev servers on Linux; the
  namespace a leaf sits in is the one it extends.
- Option 3 rejected: a module importing another gets no user half (ADR 0012),
  so `steamdb` importing `zen.core` would miss the primary user's pins and
  containers unless it named both halves, and every add-on repeats the line.
- Option 4 rejected: `__functor` shows up as an attribute wherever the tree is
  walked (`scripts/list-optional.sh`, the module/namespace pairing test), and a
  callable namespace still couldn't pick the user's half.
- Option 5 rejected: it turns the right thing into a second line every host
  must write, the same pairing problem ADR 0012 removed.

### Consequences

- Good: `optional.home.browsers.zen` is a valid import and means Zen with the
  user's half; add-ons can't arrive without their base.
- Good: unit tests in `lib/tests/user-extras.nix` pin both directions, the user
  tree's namespace, and that only the leaf's own namespace counts.
- Bad: outside the three expanded places, importing a namespace attrset fails
  as a module whose options don't exist, as it did before.
- Bad: naming a module `core` now changes what its siblings import; a module
  that is not a base for its namespace must not be called `core`.
- Neutral: a user leaf now also brings the shared leaf at its place, the mirror
  of ADR 0012's pairing; no user leaf currently has one it lacked.
