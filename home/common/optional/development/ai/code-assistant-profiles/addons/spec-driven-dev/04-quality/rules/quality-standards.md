Quality standards:

- Every new function/method should have at least one test covering its primary behavior.
- Every bug fix should include a regression test that reproduces the original bug.
- Never swallow errors silently — every catch block must re-throw, return an error result, or report to an error tracking system.
- Empty catch blocks are never acceptable.
- Error messages should include: what failed, relevant identifiers, and enough context to debug.
- Test names should describe behavior ("should return X when given Y"), not implementation ("should call method Z").
- Use the spec-reviewer agent to verify spec-related changes against acceptance criteria.
- Use the silent-failure-hunter agent periodically on modified files, especially after large changes.
