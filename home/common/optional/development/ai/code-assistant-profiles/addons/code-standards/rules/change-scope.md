Solving a task: take the first option that fully works. Does it need to exist at all? Is it
already in this codebase? Use it the way the surrounding code does. Then the standard library
or platform, then an installed dependency (never a new one for a few lines), then the minimum
code. Nothing nobody asked for: no options, wrappers or "for later" code.

Scope is everything the change must reach, not features: list the callers, tests, fixtures,
config and exports first, and what it could break for users. Then finish all of it. Be minimal
about the solution, never about the change.

Never cut validation at trust boundaries, error handling that prevents data loss, security, or
accessibility. Code you move or merge keeps its validation and error handling.
