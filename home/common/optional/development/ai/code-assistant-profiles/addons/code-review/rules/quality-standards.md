Quality standards:

- Every new function/method should have at least one test covering its primary behavior.
- Every bug fix should include a regression test that reproduces the original bug.
- Errors get re-thrown, returned as an error result, or reported to error tracking — never swallowed, and never an empty catch block.
- Error messages should include: what failed, relevant identifiers, and enough context to debug.
- Test names should describe behavior ("should return X when given Y"), not implementation ("should call method Z").
- Use the shortcut-hunter agent before calling a change done — it fails on stubs, TODOs, and swallowed errors.
- Use the silent-failure-hunter agent periodically on modified files, especially after large changes.
