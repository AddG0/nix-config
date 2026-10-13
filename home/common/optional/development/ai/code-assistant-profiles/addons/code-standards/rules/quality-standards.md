Quality standards:

- Test each module through its interface: every new behavior gets a test that calls it as a caller would and asserts on outcomes, not internals.
- Every bug fix should include a regression test that reproduces the original bug.
- Errors get re-thrown, returned as an error result, or reported to error tracking — never swallowed, and never an empty catch block.
- Error messages should include: what failed, relevant identifiers, and enough context to debug.
- Name a test for the behavior and the condition, in domain words and the repo's existing style: `rejects login when password is expired`, not `testLogin`.
