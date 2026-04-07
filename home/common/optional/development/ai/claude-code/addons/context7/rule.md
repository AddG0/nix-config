Use Context7 MCP server to fetch live documentation for libraries/frameworks.

## When to use — PROACTIVELY, not just on request

Use Context7 automatically whenever you:
- Encounter a framework/library API you're not 100% certain about
- Debug errors related to framework behavior (e.g. serialization, config, runtime modes)
- Need to know how a specific feature works (e.g. Flink batch mode, Iceberg catalog API)
- Are about to suggest a fix involving framework-specific code
- See runtime errors that reference framework classes or configuration

Do NOT guess at API behavior from training data. If you're unsure, look it up first.

"use context7" in a user message is an explicit override — but the default is to use it proactively.

## How to use

1. `resolve-library-id` to find the library (e.g. "apache flink", "apache iceberg")
2. `query-docs` with a focused topic (e.g. "POJO type serialization requirements", "batch mode REST endpoint")
3. Ground your answer in the fetched docs, cite version-specific differences
4. If docs don't cover it, say so — don't fill the gap with guesses
