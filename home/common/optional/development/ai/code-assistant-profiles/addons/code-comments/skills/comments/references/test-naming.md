# Test naming and comments

Name the **behavior**, not the implementation. Implementation-named tests
(`testLogin`) couple to internals, break on refactor, and explain nothing when
they fail. A good name reads like a description of the scenario you could say to
a non-programmer; avoid baking the method name into the test name.

Two common patterns:

- `[UnitOfWork]_[StateUnderTest]_[ExpectedBehavior]` —
  `Sum_NegativeFirstParam_ThrowsException`
- Plain-sentence — `delivery_with_a_past_date_is_invalid`

## Per framework

- **JUnit 5** — descriptive method name plus
  `@DisplayName("Register user with valid input saves to database")`.
- **pytest** — `test_` prefix, descriptive snake_case, often GIVEN/WHEN/THEN or
  SHOULD/WHEN phrasing.
- **Jest** — nested `describe`/`it`: `it('should return an access token')`.
- **Go** — `TestXxx(*testing.T)`; table-driven with a `name` field per case run
  via `t.Run`, so a failure names the case.
- **RSpec** — `describe` (subject) / `context "when…"` / `it "has a balance of
  zero"`.

## Comments inside tests

- **Separate Arrange / Act / Assert with blank lines, not `// Arrange`
  markers.** Adding the markers is usually noise; needing them means a phase is
  long enough to be a design smell.

```python
sut = Calculator()          # blank lines mark the phases — no ceremony

result = sut.add(2, 3)

assert result == 5
```

- Comment test data only when a value is non-obvious:
  `# 1001 — just above the bulk-discount threshold`.
- Comment a workaround's reason: `# gateway rejects test cards in CI`.
- Comment an assertion on *absence*: `# no email should fire for draft orders`.
