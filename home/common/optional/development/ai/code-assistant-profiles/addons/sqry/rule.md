---
description: Using the sqry MCP tools for structural code search over the call graph.
---

sqry answers structural questions — who calls this, what breaks if I change it, where is the cycle — by querying an AST graph rather than matching strings. Reach for it over `grep` when the question is about relationships (`direct_callers`, `dependency_impact`, `call_hierarchy`, `find_cycles`, `find_unused`, `trace_path`); stay with `grep` for literal text, config values, and comments, which the graph does not model. Its real edge is resolving through an interface to every implementation's callers, which no text search can do. `generate_overview` is the cheapest way to orient in an unfamiliar repo.

Its tools are deferred, so fetch the ones you need in a single `ToolSearch` call at first use rather than one lookup per tool.

The first tool call in a repo builds the index and can take minutes on a large tree — it writes `.sqry/` into the working copy (globally gitignored here). Expect that cost once, not per call. Generated and build output is skipped along with the rest of `.gitignore`, as are symbol-free files such as Java's `package-info.java`.

## Trust the per-symbol tools over the summaries

`direct_callers` is the reliable one; verified exact against `grep` on a Rust tree. The ranked numbers in `generate_overview` are computed differently and disagree with it — one symbol showed `fanIn` 16 against 46 real callers. `dependency_impact` can return zero impacted symbols for a symbol that `direct_callers` resolves fine, so a zero there means "ask `direct_callers`", never "nothing calls this".

Ignore `subsystems.couplings` and `unusedSymbols` on a Spring/Gradle codebase: couplings have been observed pointing from `src/main` into `src/integrationTest` when no such reference exists, and DI plus reflective test wiring leaves ~90% of symbols looking unused.

## Paths and ambiguity

The `path` argument takes an ordinary relative or absolute path. `file_path`, used to disambiguate a symbol, takes only the absolute path echoed in the error's `candidates` list — a repo-relative one fails with "No definition found in file". Ambiguity is sometimes between a definition and its own call site, so prefer the fully qualified candidate over the bare name.

`source_root_id` in `workspace_status` output is an opaque 8-hex token, not a path prefix; never build a path like `485f1995/src/lib.rs`.

## Java

Every Java location comes back as line 1 — the file is right, the line is not. Treat sqry as the tool that finds the file and the enclosing method, then grep that file for the line. Rust reports real line numbers.
