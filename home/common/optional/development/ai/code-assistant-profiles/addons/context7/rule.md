---
description: Loading and using the Context7 MCP tools for live library documentation.
---

The Context7 server ships its own usage instructions; this covers only what they leave out.

Both tools are deferred, so their schemas are absent until fetched and calling one cold sends untyped parameters that fail validation (`libraryName: expected string, received undefined`). Fetch both in a single call at first use — `ToolSearch` with `select:mcp__context7__resolve-library-id,mcp__context7__query-docs` — then use them for the rest of the session rather than re-searching per lookup. Being listed in `permissions.allow` does not load a schema.

`resolve-library-id` first, then `query-docs` with a focused topic rather than a broad one. Cite version-specific differences where the docs draw them, and if the docs do not answer the question, say so instead of filling the gap.
